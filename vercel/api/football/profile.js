import { getFootballPool } from '../../lib/football/db.js';
import { authenticate } from '../../lib/football/auth.js';
import { allocateStarterPack } from '../../lib/football/starterPack.js';

const playerEligibilityFilter = `COALESCE(NULLIF(p.metadata->'performanceStats'->>'appearances', '')::INT, 0) > 0`;

async function isEligibleSupportedClub(client, supportedClubId) {
  const result = await client.query(
    `
      SELECT 1
      FROM sq.football_clubs c
      WHERE c.id = $1
        AND EXISTS (
          SELECT 1
          FROM sq.football_players p
          WHERE p.club_id = c.id
            AND p.is_active = TRUE
            AND ${playerEligibilityFilter}
        )
      LIMIT 1
    `,
    [supportedClubId]
  );

  return result.rowCount === 1;
}

async function ensureProfile(client, userId) {
  await client.query(
    `
      INSERT INTO sq.football_profiles (user_id, starter_pack_status)
      VALUES ($1, 'pending')
      ON CONFLICT (user_id) DO NOTHING
    `,
    [userId]
  );
}

async function buildProfileResponse(client, userId) {
  const profileResult = await client.query(
    `
      SELECT
        p.id,
        p.user_id AS "userId",
        p.supported_club_id AS "supportedClubId",
        p.display_name AS "displayName",
        p.team_name AS "teamName",
        p.starter_pack_status AS "starterPackStatus",
        p.onboarding_completed_at AS "onboardingCompletedAt",
        c.name AS "supportedClubName",
        c.logo_url AS "supportedClubLogoUrl",
        l.name AS "supportedLeagueName"
      FROM sq.football_profiles p
      LEFT JOIN sq.football_clubs c ON c.id = p.supported_club_id
      LEFT JOIN sq.football_leagues l ON l.id = c.league_id
      WHERE p.user_id = $1
      LIMIT 1
    `,
    [userId]
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
    [userId]
  );

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
      WHERE uc.user_id = $1
        AND ${playerEligibilityFilter}
      ORDER BY uc.acquired_at ASC, uc.starter_slot_code ASC, uc.starter_slot_copy ASC
      LIMIT 30
    `,
    [userId]
  );

  const summary = summaryResult.rows[0] || {
    total_cards: 0,
    owned_cards: 0,
    starter_slots_filled: 0,
  };

  return {
    profile: profileResult.rows[0] || null,
    collectionSummary: {
      totalCards: summary.total_cards || 0,
      ownedCards: summary.owned_cards || 0,
      starterSlotsFilled: summary.starter_slots_filled || 0,
    },
    starterPackCards: cardsResult.rows,
  };
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const auth = await authenticate(req);
  if (!auth?.userId) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    await ensureProfile(client, auth.userId);

    if (req.method === 'GET') {
      const data = await buildProfileResponse(client, auth.userId);
      return res.status(200).json({ success: true, data });
    }

    if (req.method !== 'POST') {
      res.setHeader('Allow', 'GET, POST, OPTIONS');
      return res.status(405).json({ success: false, error: 'Method not allowed' });
    }

    const supportedClubId = typeof req.body?.supportedClubId === 'string' ? req.body.supportedClubId : null;
    const displayName = typeof req.body?.displayName === 'string' ? req.body.displayName.trim() : null;
    const teamName = typeof req.body?.teamName === 'string' ? req.body.teamName.trim() : null;

    if (!supportedClubId) {
      return res.status(400).json({ success: false, error: 'supportedClubId is required' });
    }

    if (!(await isEligibleSupportedClub(client, supportedClubId))) {
      return res.status(422).json({
        success: false,
        error: 'Selected club is not eligible for onboarding',
      });
    }

    await client.query('BEGIN');

    await client.query(
      `
        UPDATE sq.football_profiles
        SET supported_club_id = $2,
            display_name = COALESCE(NULLIF($3, ''), display_name),
            team_name = COALESCE(NULLIF($4, ''), team_name),
            onboarding_completed_at = COALESCE(onboarding_completed_at, NOW()),
            updated_at = NOW()
        WHERE user_id = $1
      `,
      [auth.userId, supportedClubId, displayName, teamName]
    );

    const allocation = await allocateStarterPack(client, {
      userId: auth.userId,
      supportedClubId,
    });

    await client.query('COMMIT');

    const data = await buildProfileResponse(client, auth.userId);

    return res.status(200).json({
      success: true,
      data: {
        ...data,
        allocation,
      },
    });
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // ignore rollback errors
    }

    if (error.code === '23505' && error.constraint?.includes('team_name')) {
      return res.status(409).json({ success: false, error: 'Team name already taken' });
    }

    console.error('Football profile handler failed', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to load football profile',
      details: error.message,
    });
  } finally {
    client.release();
  }
}
