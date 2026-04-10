import { getFootballPool } from '../../lib/football/db.js';
import { authenticate } from '../../lib/football/auth.js';

const playerEligibilityFilter = `COALESCE(NULLIF(p.metadata->'performanceStats'->>'appearances', '')::INT, 0) > 0`;

function parseLimit(value, fallback = 100) {
  const parsed = Number.parseInt(value ?? String(fallback), 10);
  if (!Number.isFinite(parsed) || parsed < 1) {
    return fallback;
  }
  return Math.min(parsed, 250);
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET, OPTIONS');
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const auth = await authenticate(req);
  if (!auth?.userId) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const { slot, club, search } = req.query ?? {};
  const limit = parseLimit(req.query?.limit, 100);
  const params = [auth.userId];
  const filters = ['uc.user_id = $1', playerEligibilityFilter];

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
          AND ${playerEligibilityFilter}
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
          AND ${playerEligibilityFilter}
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
          AND ${playerEligibilityFilter}
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
