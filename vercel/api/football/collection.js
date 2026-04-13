import { getFootballPool } from '../../lib/football/db.js';
import { authenticate } from '../../lib/football/auth.js';

function parseLimit(value, fallback = 100) {
  const parsed = Number.parseInt(value ?? String(fallback), 10);
  if (!Number.isFinite(parsed) || parsed < 1) {
    return fallback;
  }
  return Math.min(parsed, 250);
}

const MAX_DAILY_DISCARDS = 5;

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'DELETE') return handleDiscard(req, res);

  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET, DELETE, OPTIONS');
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const auth = await authenticate(req);
  if (!auth?.userId) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const { slot, club, search } = req.query ?? {};
  const limit = parseLimit(req.query?.limit, 100);
  const params = [auth.userId];
  const filters = ['uc.user_id = $1', "uc.ownership_status = 'owned'"];

  if (typeof slot === 'string' && slot.trim().length > 0) {
    params.push(slot.trim().toUpperCase());
    filters.push(`uc.starter_slot_code = $${params.length}`);
  }

  if (typeof club === 'string' && club.trim().length > 0) {
    params.push(club.trim());
    filters.push(`c.name = $${params.length}`);
  }

  if (typeof search === 'string' && search.trim().length >= 2) {
    params.push(`%${search.trim()}%`);
    filters.push(`(p.name ILIKE $${params.length} OR c.name ILIKE $${params.length})`);
  }

  params.push(limit);
  const whereClause = `WHERE ${filters.join(' AND ')}`;

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    const cardsResult = await client.query(
      `
        SELECT
          uc.id AS "userCardId",
          uc.player_id AS "playerId",
          uc.card_template_id AS "cardTemplateId",
          p.club_id AS "clubId",
          uc.starter_slot_code AS "starterSlotCode",
          uc.starter_slot_copy AS "starterSlotCopy",
          uc.ownership_status AS "ownershipStatus",
          uc.acquired_at AS "acquiredAt",
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
        FROM sq.football_user_cards uc
        INNER JOIN sq.football_players p ON p.id = uc.player_id
        LEFT JOIN sq.football_clubs c ON c.id = p.club_id
        LEFT JOIN sq.football_leagues l ON l.id = p.league_id
        ${whereClause}
        ORDER BY COALESCE(uc.starter_slot_code, 'ZZZ') ASC, uc.starter_slot_copy ASC NULLS LAST, p.name ASC
        LIMIT $${params.length}
      `,
      params
    );

    const slotsResult = await client.query(
      `
        SELECT DISTINCT uc.starter_slot_code AS slot
        FROM sq.football_user_cards uc
        INNER JOIN sq.football_players p ON p.id = uc.player_id
        WHERE uc.user_id = $1 AND uc.starter_slot_code IS NOT NULL
          AND uc.ownership_status = 'owned'
        ORDER BY slot ASC
      `,
      [auth.userId]
    );

    const clubsResult = await client.query(
      `
        SELECT DISTINCT c.name AS club_name
        FROM sq.football_user_cards uc
        INNER JOIN sq.football_players p ON p.id = uc.player_id
        LEFT JOIN sq.football_clubs c ON c.id = p.club_id
        WHERE uc.user_id = $1 AND c.name IS NOT NULL
          AND uc.ownership_status = 'owned'
        ORDER BY c.name ASC
      `,
      [auth.userId]
    );

    const summaryResult = await client.query(
      `
        SELECT
          COUNT(*)::INT AS total_cards,
          COUNT(*) FILTER (WHERE uc.ownership_status = 'owned')::INT AS owned_cards,
          COUNT(DISTINCT uc.starter_slot_code)::INT AS starter_slots_filled
        FROM sq.football_user_cards uc
        INNER JOIN sq.football_players p ON p.id = uc.player_id
        WHERE uc.user_id = $1
          AND uc.ownership_status = 'owned'
      `,
      [auth.userId]
    );

    const summary = summaryResult.rows[0] || {
      total_cards: 0,
      owned_cards: 0,
      starter_slots_filled: 0,
    };

    return res.status(200).json({
      success: true,
      data: {
        cards: cardsResult.rows,
        availableSlots: slotsResult.rows.map((row) => row.slot),
        availableClubs: clubsResult.rows.map((row) => row.club_name),
        summary: {
          totalCards: summary.total_cards || 0,
          ownedCards: summary.owned_cards || 0,
          starterSlotsFilled: summary.starter_slots_filled || 0,
        },
      },
    });
  } catch (error) {
    console.error('GET /api/football/collection failed', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to load football collection',
      details: error.message,
    });
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// DELETE /api/football/collection  { userCardId }  — discard a card (max 5/day)
// ---------------------------------------------------------------------------
async function handleDiscard(req, res) {
  const auth = await authenticate(req);
  if (!auth?.userId) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const userCardId = typeof req.body?.userCardId === 'string'
    ? req.body.userCardId.trim() : '';

  if (!userCardId) {
    return res.status(400).json({ success: false, error: 'Missing userCardId' });
  }

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const today = new Date().toISOString().slice(0, 10);

    const profileResult = await client.query(
      `SELECT daily_discard_date, COALESCE(daily_discards_used, 0) AS daily_discards_used
       FROM sq.football_profiles WHERE user_id = $1 FOR UPDATE LIMIT 1`,
      [auth.userId]
    );
    const profile = profileResult.rows[0];
    const discardDate = profile?.daily_discard_date
      ? String(profile.daily_discard_date).slice(0, 10) : null;
    const usedToday = discardDate === today ? (profile?.daily_discards_used ?? 0) : 0;

    if (usedToday >= MAX_DAILY_DISCARDS) {
      await client.query('ROLLBACK');
      return res.status(429).json({
        success: false,
        error: `Daily discard limit reached (${MAX_DAILY_DISCARDS} per day)`,
        discardsRemaining: 0,
      });
    }

    const cardResult = await client.query(
      `SELECT uc.id::text AS "userCardId"
       FROM sq.football_user_cards uc
       WHERE uc.id::text = $1
         AND uc.user_id = $2
         AND uc.ownership_status = 'owned'
         AND uc.starter_slot_code IS NULL
       LIMIT 1`,
      [userCardId, auth.userId]
    );

    if (cardResult.rowCount !== 1) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: 'Card not found, not owned, or currently in a squad slot',
      });
    }

    const listedResult = await client.query(
      `SELECT id FROM sq.football_exchange_listings
       WHERE user_card_id = $1 AND status = 'active' LIMIT 1`,
      [userCardId]
    );
    if (listedResult.rowCount > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        success: false,
        error: 'Card is listed on the exchange — remove it first',
      });
    }

    await client.query(
      `UPDATE sq.football_user_cards
       SET ownership_status = 'discarded',
           metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
             'disposition', 'user_discarded',
             'discardedAt', NOW()
           )
       WHERE id::text = $1 AND user_id = $2`,
      [userCardId, auth.userId]
    );

    await client.query(
      `UPDATE sq.football_profiles
       SET daily_discard_date  = $1::DATE,
           daily_discards_used = CASE WHEN daily_discard_date = $1::DATE
                                      THEN daily_discards_used + 1
                                      ELSE 1 END
       WHERE user_id = $2`,
      [today, auth.userId]
    );

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      data: { userCardId, discardsRemaining: MAX_DAILY_DISCARDS - (usedToday + 1) },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('DELETE /api/football/collection failed', error);
    return res.status(500).json({ success: false, error: 'Failed to discard card', details: error.message });
  } finally {
    client.release();
  }
}
