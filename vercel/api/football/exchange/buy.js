import { getFootballPool } from '../../../lib/football/db.js';
import { authenticate } from '../../../lib/football/auth.js';

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

// ---------------------------------------------------------------------------
// POST /api/football/exchange/buy  { listingId }
//
// Buyer pays rating_cost from their budget (active listing ratings / 2 + balance).
// Seller receives: card_rating + 2 bonus points added to trade_rating_balance.
// The purchased card transfers ownership to the buyer.
// ---------------------------------------------------------------------------
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const auth = await authenticate(req);
  if (!auth?.userId) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const listingId = typeof req.body?.listingId === 'string'
    ? req.body.listingId.trim() : '';

  if (!listingId) {
    return res.status(400).json({ success: false, error: 'Missing listingId' });
  }

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Lock and verify the listing
    const listingResult = await client.query(
      `
        SELECT
          el.id::text AS "listingId",
          el.seller_user_id AS "sellerUserId",
          el.user_card_id::text AS "userCardId",
          el.card_rating::FLOAT8 AS "cardRating",
          el.rating_cost::FLOAT8 AS "ratingCost",
          el.status,
          el.expires_at AS "expiresAt"
        FROM sq.football_exchange_listings el
        WHERE el.id::text = $1
          AND el.status = 'active'
          AND el.expires_at > NOW()
        FOR UPDATE SKIP LOCKED
        LIMIT 1
      `,
      [listingId]
    );

    if (listingResult.rowCount !== 1) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Listing not found or no longer active' });
    }

    const listing = listingResult.rows[0];

    if (listing.sellerUserId === auth.userId) {
      await client.query('ROLLBACK');
      return res.status(409).json({ success: false, error: 'Cannot buy your own listing' });
    }

    // Calculate buyer's budget:
    //   sum(active listing card ratings) / 2  +  trade_rating_balance
    const budgetResult = await client.query(
      `
        SELECT
          COALESCE(SUM(el.card_rating), 0) / 2.0        AS "listingBudget",
          COALESCE(fp.trade_rating_balance, 0)           AS "bonusBalance"
        FROM sq.football_profiles fp
        LEFT JOIN sq.football_exchange_listings el
          ON el.seller_user_id = $1
         AND el.status = 'active'
         AND el.id::text <> $2
        WHERE fp.user_id = $1
        GROUP BY fp.trade_rating_balance
      `,
      [auth.userId, listingId]
    );

    const budgetRow = budgetResult.rows[0] ?? { listingBudget: '0', bonusBalance: '0' };
    const totalBudget = parseFloat(budgetRow.listingBudget) + parseFloat(budgetRow.bonusBalance);
    const ratingCost = parseFloat(listing.ratingCost);

    if (totalBudget < ratingCost) {
      await client.query('ROLLBACK');
      return res.status(402).json({
        success: false,
        error: 'Insufficient trade budget',
        details: `Need ${ratingCost} pts, have ${totalBudget.toFixed(2)} pts`,
      });
    }

    // Deduct cost from buyer's bonus balance if needed
    // We consume bonus balance first, then implicitly the listing budget is "used"
    // by removing the active listing (which reduces future budget naturally)
    // If buyer's bonus balance >= cost → deduct from balance; else deduct what we can
    const bonusBalance = parseFloat(budgetRow.bonusBalance);
    const deductFromBonus = Math.min(bonusBalance, ratingCost);

    if (deductFromBonus > 0) {
      await client.query(
        `UPDATE sq.football_profiles
         SET trade_rating_balance = trade_rating_balance - $1
         WHERE user_id = $2`,
        [deductFromBonus, auth.userId]
      );
    }

    // Transfer the card to buyer
    await client.query(
      `UPDATE sq.football_user_cards
       SET user_id = $1,
           acquisition_type = 'trade',
           acquired_at = NOW(),
           starter_slot_code = NULL,
           starter_slot_copy = NULL,
           metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
             'previousOwnerId', $2,
             'purchasedViaExchange', TRUE,
             'listingId', $3,
             'purchasedAt', NOW()
           )
       WHERE id::text = $4`,
      [auth.userId, listing.sellerUserId, listingId, listing.userCardId]
    );

    // Award seller: card_rating + 2 bonus points
    const sellerBonus = parseFloat(listing.cardRating ?? 0) + 2;
    await client.query(
      `INSERT INTO sq.football_profiles (user_id, trade_rating_balance)
       VALUES ($1, $2)
       ON CONFLICT (user_id) DO UPDATE
       SET trade_rating_balance = sq.football_profiles.trade_rating_balance + $2`,
      [listing.sellerUserId, sellerBonus]
    );

    // Close the listing
    await client.query(
      `UPDATE sq.football_exchange_listings
       SET status = 'sold',
           buyer_user_id = $1,
           completed_at = NOW()
       WHERE id::text = $2`,
      [auth.userId, listingId]
    );

    // Fetch the transferred card for the response
    const acquiredCardResult = await client.query(
      `
        SELECT ${toCardRowSelect('uc')}
        FROM sq.football_user_cards uc
        INNER JOIN sq.football_players p ON p.id = uc.player_id
        LEFT JOIN sq.football_clubs c ON c.id = p.club_id
        LEFT JOIN sq.football_leagues l ON l.id = p.league_id
        WHERE uc.id::text = $1
          AND uc.user_id = $2
        LIMIT 1
      `,
      [listing.userCardId, auth.userId]
    );

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      data: {
        listingId,
        acquiredCard: acquiredCardResult.rows[0] ?? null,
        costPaid: ratingCost,
      },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('POST /api/football/exchange/buy failed', error);
    return res.status(500).json({ success: false, error: 'Failed to complete purchase', details: error.message });
  } finally {
    client.release();
  }
}
