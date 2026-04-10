import { getFootballPool } from '../../lib/football/db.js';
import { authenticate } from '../../lib/football/auth.js';

const playerEligibilityFilter = `COALESCE(NULLIF(p.metadata->'performanceStats'->>'appearances', '')::INT, 0) > 0`;

function toCardRowSelect(alias = 'uc') {
  return `
    ${alias}.id AS "userCardId",
    ${alias}.player_id AS "playerId",
    ${alias}.card_template_id AS "cardTemplateId",
    p.club_id AS "clubId",
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
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const auth = await authenticate(req);
  if (!auth?.userId) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const swappedOutUserCardId = typeof req.body?.swappedOutUserCardId === 'string'
    ? req.body.swappedOutUserCardId.trim()
    : '';

  const excludedPlayerIds = Array.isArray(req.body?.excludedPlayerIds)
    ? req.body.excludedPlayerIds.map((value) => String(value || '').trim()).filter(Boolean)
    : [];

  if (!swappedOutUserCardId) {
    return res.status(400).json({ success: false, error: 'Missing swappedOutUserCardId' });
  }

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const currentCardResult = await client.query(
      `
        SELECT id::text AS "userCardId", player_id::text AS "playerId"
        FROM sq.football_user_cards
        WHERE id::text = $1
          AND user_id = $2
          AND ownership_status = 'owned'
        LIMIT 1
      `,
      [swappedOutUserCardId, auth.userId]
    );

    if (currentCardResult.rowCount !== 1) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Swap card not found' });
    }

    const currentCard = currentCardResult.rows[0];
    const candidateExcludedPlayerIds = Array.from(new Set([...excludedPlayerIds, currentCard.playerId]));

    const candidateResult = await client.query(
      `
        SELECT
          ct.id::text AS "cardTemplateId",
          p.id::text AS "playerId"
        FROM sq.football_card_templates ct
        INNER JOIN sq.football_players p ON p.id = ct.player_id
        WHERE p.is_active = TRUE
          AND ${playerEligibilityFilter}
          AND ct.card_type = 'base'
          AND ct.rarity = 'common'
          AND NOT (p.id::text = ANY($1::text[]))
        ORDER BY RANDOM()
        LIMIT 1
      `,
      [candidateExcludedPlayerIds]
    );

    if (candidateResult.rowCount !== 1) {
      await client.query('ROLLBACK');
      return res.status(409).json({ success: false, error: 'No eligible swap reward available' });
    }

    const candidate = candidateResult.rows[0];

    await client.query(
      `
        UPDATE sq.football_user_cards
        SET ownership_status = 'traded',
            starter_slot_code = NULL,
            starter_slot_copy = NULL,
            metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
              'swappedAt', NOW(),
              'swapReplacementPlayerId', $2::text,
              'disposition', 'swap'
            )
        WHERE id::text = $1
          AND user_id = $3
      `,
      [swappedOutUserCardId, candidate.playerId, auth.userId]
    );

    const insertedResult = await client.query(
      `
        INSERT INTO sq.football_user_cards (
          user_id,
          card_template_id,
          player_id,
          starter_pack_id,
          starter_slot_code,
          starter_slot_copy,
          acquisition_type,
          ownership_status,
          acquired_at,
          metadata
        )
        VALUES ($1, $2, $3, NULL, NULL, NULL, 'trade', 'owned', NOW(), $4::jsonb)
        RETURNING id::text AS "userCardId"
      `,
      [
        auth.userId,
        candidate.cardTemplateId,
        candidate.playerId,
        JSON.stringify({
          swappedOutUserCardId,
          excludedPlayerIds: candidateExcludedPlayerIds,
          acquisitionSource: 'swap',
        }),
      ]
    );

    const newUserCardId = insertedResult.rows[0].userCardId;
    const rewardCardResult = await client.query(
      `
        SELECT
          ${toCardRowSelect('uc')}
        FROM sq.football_user_cards uc
        INNER JOIN sq.football_players p ON p.id = uc.player_id
        LEFT JOIN sq.football_clubs c ON c.id = p.club_id
        LEFT JOIN sq.football_leagues l ON l.id = p.league_id
        WHERE uc.id::text = $1
          AND uc.user_id = $2
        LIMIT 1
      `,
      [newUserCardId, auth.userId]
    );

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      data: {
        swappedOutUserCardId,
        rewardCard: rewardCardResult.rows[0],
      },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('POST /api/football/swap failed', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to execute football swap',
      details: error.message,
    });
  } finally {
    client.release();
  }
}