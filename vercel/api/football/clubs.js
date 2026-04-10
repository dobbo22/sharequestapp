import { getFootballPool } from '../../lib/football/db.js';
import { getFootballProviderPreference } from '../../lib/football/providerPreference.js';

function parseLimit(value) {
  const parsed = Number.parseInt(value ?? '50', 10);
  if (!Number.isFinite(parsed) || parsed < 1) {
    return 50;
  }
  return Math.min(parsed, 100);
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
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const pool = getFootballPool();
  const { leagueId, search } = req.query ?? {};
  const limit = parseLimit(req.query?.limit);
  const parameterOffset = 2;

  const whereParts = [];
  const params = [];

  if (leagueId) {
    params.push(leagueId);
    whereParts.push(`c.league_id = $${params.length + parameterOffset}`);
  }

  if (typeof search === 'string' && search.trim().length >= 2) {
    params.push(`%${search.trim()}%`);
    whereParts.push(`c.name ILIKE $${params.length + parameterOffset}`);
  }

  params.push(limit);

  const whereClause = whereParts.length > 0 ? `AND ${whereParts.join(' AND ')}` : '';

  try {
    const client = await pool.connect();
    try {
      const providerPreference = await getFootballProviderPreference();
      const result = await client.query(
        `
          WITH league_candidates AS (
            SELECT
              id,
              name,
              tier,
              season_year,
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
              name,
              tier,
              season_year,
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
            SELECT id, name, tier, season_year
            FROM ranked_leagues
            WHERE provider_rank = 1
          )
          SELECT
            c.id,
            c.api_football_team_id AS "apiFootballTeamId",
            c.name,
            c.short_name AS "shortName",
            c.code,
            c.logo_url AS "logoUrl",
            c.venue_name AS "venueName",
            c.venue_city AS "venueCity",
            l.id AS "leagueId",
            l.name AS "leagueName",
            l.tier AS "leagueTier",
            l.season_year AS "seasonYear"
          FROM sq.football_clubs c
          INNER JOIN preferred_leagues l ON l.id = c.league_id
          WHERE EXISTS (
            SELECT 1
            FROM sq.football_players p
            WHERE p.club_id = c.id
              AND p.is_active = TRUE
              AND COALESCE(NULLIF(p.metadata->'performanceStats'->>'appearances', '')::INT, 0) > 0
          )
          ${whereClause}
          ORDER BY l.tier ASC NULLS LAST, c.name ASC
          LIMIT $${params.length + 2}
        `,
        [providerPreference.preferredLeagueIds, providerPreference.fallbackLeagueIds, ...params]
      );

      return res.status(200).json({
        success: true,
        data: result.rows,
      });
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('GET /api/football/clubs failed', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to load football clubs',
    });
  }
}