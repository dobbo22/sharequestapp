import { getFootballPool } from '../../lib/football/db.js';
import { getFootballGameConfig } from '../../lib/football/gameConfig.js';
import { getFootballProviderPreference } from '../../lib/football/providerPreference.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET, OPTIONS');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const pool = getFootballPool();

  try {
    const client = await pool.connect();
    try {
      const [config, providerPreference] = await Promise.all([
        getFootballGameConfig(),
        getFootballProviderPreference(),
      ]);

      const [slotsResult, leaguesResult, statsResult] = await Promise.all([
        client.query(`
          SELECT
            slot_code AS "slotCode",
            display_name AS "displayName",
            sort_order AS "sortOrder",
            starter_quantity AS "starterQuantity"
          FROM sq.football_position_slots
          ORDER BY sort_order ASC
        `),
        client.query(
          `
            WITH league_candidates AS (
              SELECT
                id,
                api_football_league_id,
                season_year,
                name,
                slug,
                tier,
                logo_url,
                is_active,
                updated_at,
                MAX(season_year) OVER (PARTITION BY LOWER(name)) AS latest_season_year,
                CASE
                  WHEN api_football_league_id = ANY($1::INT[]) THEN 0
                  WHEN api_football_league_id = ANY($2::INT[]) THEN 1
                  ELSE 2
                END AS provider_priority
              FROM sq.football_leagues
              WHERE country = 'England'
            ),
            ranked_leagues AS (
              SELECT
                id,
                api_football_league_id,
                season_year,
                name,
                slug,
                tier,
                logo_url,
                is_active,
                ROW_NUMBER() OVER (
                  PARTITION BY LOWER(name)
                  ORDER BY CASE
                    WHEN season_year = latest_season_year THEN 0
                    ELSE 1
                  END,
                  provider_priority,
                  season_year DESC,
                  updated_at DESC,
                  id ASC
                ) AS provider_rank
              FROM league_candidates
            )
            SELECT
              id,
              api_football_league_id AS "apiFootballLeagueId",
              season_year AS "seasonYear",
              name,
              slug,
              tier,
              logo_url AS "logoUrl",
              is_active AS "isActive"
            FROM ranked_leagues
            WHERE provider_rank = 1
            ORDER BY tier ASC, season_year DESC, name ASC
          `,
          [providerPreference.preferredLeagueIds, providerPreference.fallbackLeagueIds]
        ),
        client.query(
          `
            WITH league_candidates AS (
              SELECT
                id,
                season_year,
                name,
                updated_at,
                MAX(season_year) OVER (PARTITION BY LOWER(name)) AS latest_season_year,
                CASE
                  WHEN api_football_league_id = ANY($1::INT[]) THEN 0
                  WHEN api_football_league_id = ANY($2::INT[]) THEN 1
                  ELSE 2
                END AS provider_priority
              FROM sq.football_leagues
              WHERE country = 'England'
            ),
            ranked_leagues AS (
              SELECT
                id,
                ROW_NUMBER() OVER (
                  PARTITION BY LOWER(name)
                  ORDER BY CASE
                    WHEN season_year = latest_season_year THEN 0
                    ELSE 1
                  END,
                  provider_priority,
                  season_year DESC,
                  updated_at DESC,
                  id ASC
                ) AS provider_rank
              FROM league_candidates
            ),
            preferred_leagues AS (
              SELECT id
              FROM ranked_leagues
              WHERE provider_rank = 1
            )
            SELECT
              (SELECT COUNT(*)::INT FROM preferred_leagues) AS leagues_count,
              (SELECT COUNT(*)::INT FROM sq.football_clubs c INNER JOIN preferred_leagues l ON l.id = c.league_id) AS clubs_count,
              (SELECT COUNT(*)::INT FROM sq.football_players p INNER JOIN preferred_leagues l ON l.id = p.league_id) AS players_count,
              (SELECT COUNT(*)::INT FROM sq.football_profiles) AS profiles_count,
              (SELECT COUNT(*)::INT FROM sq.football_user_cards) AS user_cards_count
          `,
          [providerPreference.preferredLeagueIds, providerPreference.fallbackLeagueIds]
        ),
      ]);

      return res.status(200).json({
        success: true,
        data: {
          gameConfig: config,
          starterSlots: slotsResult.rows,
          leagues: leaguesResult.rows,
          stats: {
            leaguesCount: statsResult.rows[0].leagues_count,
            clubsCount: statsResult.rows[0].clubs_count,
            playersCount: statsResult.rows[0].players_count,
            profilesCount: statsResult.rows[0].profiles_count,
            userCardsCount: statsResult.rows[0].user_cards_count,
          },
        },
      });
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('GET /api/football/bootstrap failed', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to load football bootstrap data',
    });
  }
}