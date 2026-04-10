import { getFootballPool } from '../../lib/football/db.js';
import { authenticate } from '../../lib/football/auth.js';

// Shared card SELECT fragment (matches swap.js)
function toCardRowSelect(alias = 'uc') {
  return `
    ${alias}.id::text AS "userCardId",
    ${alias}.player_id::text AS "playerId",
    ${alias}.card_template_id::text AS "cardTemplateId",
    p.club_id::text AS "clubId",
    ${alias}.starter_slot_code AS "starterSlotCode",
    ${alias}.starter_slot_copy AS "starterSlotCopy",
    ${alias}.ownership_status AS "ownershipStatus",
    ${alias}.acquired_at AS "acquiredAt",
    p.name AS "playerName",
    p.age AS "age",
    p.position_label AS "positionLabel",
    p.metadata->'detailedPosition'->>'name' AS "detailedPositionLabel",
    NULLIF(p.metadata->'player'->>'height', '')::INT AS "heightCm",
    NULLIF(p.metadata->'player'->>'weight', '')::INT AS "weightKg",
    NULLIF(p.metadata->'performanceStats'->>'appearances', '')::INT AS "appearances",
    NULLIF(p.metadata->'performanceStats'->>'goals', '')::INT AS "goals",
    NULLIF(p.metadata->'performanceStats'->>'assists', '')::INT AS "assists",
    NULLIF(p.metadata->'performanceStats'->>'tackles', '')::INT AS "tackles",
    NULLIF(p.metadata->'performanceStats'->>'shotsOnTarget', '')::INT AS "shotsOnTarget",
    NULLIF(p.metadata->'performanceStats'->>'saves', '')::INT AS "saves",
    NULLIF(p.metadata->'performanceStats'->>'cleanSheets', '')::INT AS "cleanSheets",
    NULLIF(p.metadata->'performanceStats'->>'goalsConceded', '')::INT AS "goalsConceded",
    NULLIF(p.metadata->'performanceStats'->>'passes', '')::INT AS "passes",
    NULLIF(p.metadata->'transferSummary'->>'latestTransferAmount', '')::FLOAT8 AS "latestTransferAmount",
    NULLIF(p.metadata->'ratingSummary'->>'overall', '')::FLOAT8 AS "ratingOutOfTen",
    p.metadata->'ratingSummary'->>'source' AS "ratingSource",
    p.metadata->'ratingSummary'->>'tier' AS "ratingTier",
    NULLIF(CASE WHEN p.photo_url LIKE '%placeholder%' THEN NULL ELSE p.photo_url END, '') AS "photoUrl",
    c.name AS "clubName",
    c.logo_url AS "clubLogoUrl",
    l.name AS "leagueName",
    l.season_year AS "seasonYear"
  `;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const auth = await authenticate(req);
  if (!auth?.userId) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  if (req.method === 'GET')    return handleGet(req, res, auth);
  if (req.method === 'POST')   return handlePost(req, res, auth);
  if (req.method === 'DELETE') return handleDelete(req, res, auth);

  res.setHeader('Allow', 'GET, POST, DELETE, OPTIONS');
  return res.status(405).json({ success: false, error: 'Method not allowed' });
}

// ---------------------------------------------------------------------------
// GET /api/football/exchange
// Returns all active marketplace listings + caller's own listings of any status
// ---------------------------------------------------------------------------
async function handleGet(req, res, auth) {
  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    // Expire any listings that have passed their window (lazy expiry)
    await client.query(`
      UPDATE sq.football_exchange_listings
      SET status = 'expired'
      WHERE status = 'active' AND expires_at <= NOW()
    `);

    // Discard expired cards that weren't sold — use subquery to avoid metadata ambiguity
    await client.query(`
      UPDATE sq.football_user_cards
      SET ownership_status = 'traded',
          metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'disposition', 'exchange_expired',
            'discardedAt', NOW()
          )
      WHERE id IN (
        SELECT user_card_id
        FROM sq.football_exchange_listings
        WHERE status = 'expired'
          AND metadata->>'cardDiscarded' IS NULL
      )
      AND ownership_status = 'owned'
    `);

    // Mark those listings so we don't double-discard
    await client.query(`
      UPDATE sq.football_exchange_listings
      SET metadata = metadata || '{"cardDiscarded": true}'::jsonb
      WHERE status = 'expired'
        AND metadata->>'cardDiscarded' IS NULL
    `);

    // Fetch marketplace: active listings from others
    const marketResult = await client.query(
      `
        SELECT
          el.id::text AS "listingId",
          el.seller_user_id AS "sellerUserId",
          fu.username AS "sellerName",
          el.card_rating AS "cardRating",
          el.rating_cost AS "ratingCost",
          el.listed_at AS "listedAt",
          el.expires_at AS "expiresAt",
          el.removable_at AS "removableAt",
          el.status,
          ${toCardRowSelect('uc')}
        FROM sq.football_exchange_listings el
        INNER JOIN sq.football_user_cards uc ON uc.id = el.user_card_id
        INNER JOIN sq.football_players p ON p.id = uc.player_id
        LEFT JOIN sq.football_clubs c ON c.id = p.club_id
        LEFT JOIN sq.football_leagues l ON l.id = p.league_id
        LEFT JOIN sq.football_users fu ON fu.id::text = el.seller_user_id
        WHERE el.status = 'active'
          AND el.seller_user_id <> $1
        ORDER BY el.listed_at DESC
        LIMIT 100
      `,
      [auth.userId]
    );

    // Fetch own listings (any status, last 48h)
    const myResult = await client.query(
      `
        SELECT
          el.id::text AS "listingId",
          el.seller_user_id AS "sellerUserId",
          fu.username AS "sellerName",
          el.card_rating AS "cardRating",
          el.rating_cost AS "ratingCost",
          el.listed_at AS "listedAt",
          el.expires_at AS "expiresAt",
          el.removable_at AS "removableAt",
          el.status,
          ${toCardRowSelect('uc')}
        FROM sq.football_exchange_listings el
        INNER JOIN sq.football_user_cards uc ON uc.id = el.user_card_id
        INNER JOIN sq.football_players p ON p.id = uc.player_id
        LEFT JOIN sq.football_clubs c ON c.id = p.club_id
        LEFT JOIN sq.football_leagues l ON l.id = p.league_id
        LEFT JOIN sq.football_users fu ON fu.id::text = el.seller_user_id
        WHERE el.seller_user_id = $1
          AND el.listed_at >= NOW() - INTERVAL '48 hours'
        ORDER BY el.listed_at DESC
        LIMIT 20
      `,
      [auth.userId]
    );

    // Fetch trade_rating_balance
    const profileResult = await client.query(
      `SELECT COALESCE(trade_rating_balance, 0) AS "tradeRatingBalance"
       FROM sq.football_profiles WHERE user_id = $1 LIMIT 1`,
      [auth.userId]
    );
    const tradeRatingBalance = parseFloat(profileResult.rows[0]?.tradeRatingBalance ?? 0);

    return res.status(200).json({
      success: true,
      data: {
        marketplace: marketResult.rows,
        myListings: myResult.rows,
        tradeRatingBalance,
      },
    });
  } catch (error) {
    console.error('GET /api/football/exchange failed', error);
    return res.status(500).json({ success: false, error: 'Failed to fetch exchange listings', details: error.message });
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// POST /api/football/exchange  { userCardId }
// List a card on the exchange. Max 5 active listings per user.
// ---------------------------------------------------------------------------
async function handlePost(req, res, auth) {
  const userCardId = typeof req.body?.userCardId === 'string'
    ? req.body.userCardId.trim() : '';

  if (!userCardId) {
    return res.status(400).json({ success: false, error: 'Missing userCardId' });
  }

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Check max 5 active listings
    const activeCountResult = await client.query(
      `SELECT COUNT(*) AS count FROM sq.football_exchange_listings
       WHERE seller_user_id = $1 AND status = 'active'`,
      [auth.userId]
    );
    if (parseInt(activeCountResult.rows[0].count, 10) >= 5) {
      await client.query('ROLLBACK');
      return res.status(409).json({ success: false, error: 'Maximum 5 active listings allowed' });
    }

    // Verify card is owned by user and not already listed
    const cardResult = await client.query(
      `
        SELECT
          uc.id::text AS "userCardId",
          uc.player_id::text AS "playerId",
          NULLIF(p.metadata->'ratingSummary'->>'overall', '')::FLOAT8 AS "ratingOutOfTen"
        FROM sq.football_user_cards uc
        INNER JOIN sq.football_players p ON p.id = uc.player_id
        WHERE uc.id::text = $1
          AND uc.user_id = $2
          AND uc.ownership_status = 'owned'
        LIMIT 1
      `,
      [userCardId, auth.userId]
    );

    if (cardResult.rowCount !== 1) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Card not found or not owned' });
    }

    // Check not already actively listed
    const alreadyListed = await client.query(
      `SELECT id FROM sq.football_exchange_listings
       WHERE user_card_id = $1 AND status = 'active' LIMIT 1`,
      [userCardId]
    );
    if (alreadyListed.rowCount > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ success: false, error: 'Card is already listed on the exchange' });
    }

    const card = cardResult.rows[0];
    const cardRating = card.ratingOutOfTen ?? 0;
    const ratingCost = Math.round((cardRating / 2) * 100) / 100;

    const insertResult = await client.query(
      `
        INSERT INTO sq.football_exchange_listings
          (seller_user_id, user_card_id, player_id, card_rating, rating_cost,
           expires_at, removable_at)
        VALUES ($1, $2, $3, $4, $5,
                NOW() + INTERVAL '24 hours',
                NOW() + INTERVAL '6 hours')
        RETURNING id::text AS "listingId", listed_at AS "listedAt",
                  expires_at AS "expiresAt", removable_at AS "removableAt"
      `,
      [auth.userId, userCardId, card.playerId, cardRating, ratingCost]
    );

    await client.query('COMMIT');

    return res.status(201).json({
      success: true,
      data: insertResult.rows[0],
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('POST /api/football/exchange failed', error);
    return res.status(500).json({ success: false, error: 'Failed to create listing', details: error.message });
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// DELETE /api/football/exchange?listingId=xxx
// Remove own listing. Only allowed after 6 hours (removable_at).
// ---------------------------------------------------------------------------
async function handleDelete(req, res, auth) {
  const listingId = typeof req.query?.listingId === 'string'
    ? req.query.listingId.trim() : '';

  if (!listingId) {
    return res.status(400).json({ success: false, error: 'Missing listingId' });
  }

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const listingResult = await client.query(
      `SELECT id::text, seller_user_id, user_card_id::text, status, removable_at
       FROM sq.football_exchange_listings
       WHERE id::text = $1 AND seller_user_id = $2
       LIMIT 1`,
      [listingId, auth.userId]
    );

    if (listingResult.rowCount !== 1) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Listing not found' });
    }

    const listing = listingResult.rows[0];

    if (listing.status !== 'active') {
      await client.query('ROLLBACK');
      return res.status(409).json({ success: false, error: 'Listing is no longer active' });
    }

    if (new Date() < new Date(listing.removable_at)) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        success: false,
        error: 'Listing cannot be removed yet — must wait 6 hours after listing',
        removableAt: listing.removable_at,
      });
    }

    // Mark listing as removed
    await client.query(
      `UPDATE sq.football_exchange_listings SET status = 'removed', completed_at = NOW()
       WHERE id::text = $1`,
      [listingId]
    );

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      data: { listingId, userCardId: listing.user_card_id },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('DELETE /api/football/exchange failed', error);
    return res.status(500).json({ success: false, error: 'Failed to remove listing', details: error.message });
  } finally {
    client.release();
  }
}
