#!/usr/bin/env node
import { Pool } from 'pg';

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const value = argv[index + 1] && !argv[index + 1].startsWith('--') ? argv[index + 1] : 'true';
    args[key] = value;
  }
  return args;
}

function parseOptionalPositiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return parsed;
}

function readHeaderNumber(headers, name, fallback) {
  const rawValue = headers.get(name);
  if (rawValue === null || rawValue === undefined || rawValue === '') {
    return fallback;
  }

  const parsed = Number(rawValue);
  return Number.isFinite(parsed) ? parsed : fallback;
}

const args = parseArgs(process.argv.slice(2));

const base = process.env.API_FOOTBALL_BASE_URL || 'https://v3.football.api-sports.io';
const apiKey = process.env.API_FOOTBALL_KEY;
const connectionString = process.env.FOOTBALL_DATABASE_URL;
const season = 2024;
const premierLeagueApiId = 39;
const startPage = parseOptionalPositiveInteger(args['start-page'], 2);

if (!apiKey) {
  console.error('Missing API_FOOTBALL_KEY');
  process.exit(1);
}

if (!connectionString) {
  console.error('Missing FOOTBALL_DATABASE_URL');
  process.exit(1);
}

function mapPositionToSlot(positionLabel) {
  const value = String(positionLabel || '').toLowerCase();
  if (value.includes('goalkeeper')) return 'GK';
  if (value.includes('right back')) return 'RB';
  if (value.includes('left back')) return 'LB';
  if (value.includes('defender')) return value.includes('left') ? 'LCB' : 'RCB';
  if (value.includes('midfielder')) {
    if (value.includes('right')) return 'RM';
    if (value.includes('left')) return 'LM';
    return 'CM';
  }
  if (value.includes('winger')) {
    if (value.includes('right')) return 'RW';
    if (value.includes('left')) return 'LW';
  }
  if (value.includes('forward') || value.includes('striker') || value.includes('attacker')) return 'ST';
  return null;
}

const pool = new Pool({
  connectionString,
  ssl: { rejectUnauthorized: false },
  max: parseInt(process.env.FOOTBALL_PG_MAX_CLIENTS || '3', 10),
});

const client = await pool.connect();
const summary = {
  season,
  league: 'Premier League',
  startPage,
  lastPageAttempted: 1,
  pagesFetched: 0,
  playersUpserted: 0,
  templatesUpserted: 0,
  playersSkippedWithoutClub: 0,
  stoppedBecause: null,
  headers: null,
};

try {
  await client.query("SET search_path TO sq, public");

  const leagueResult = await client.query(
    `SELECT id FROM sq.football_leagues WHERE api_football_league_id = $1 AND season_year = $2 LIMIT 1`,
    [premierLeagueApiId, season]
  );
  const leagueId = leagueResult.rows[0]?.id;
  if (!leagueId) {
    throw new Error('Premier League row not found in sq.football_leagues');
  }

  const clubsResult = await client.query(
    `SELECT id, api_football_team_id FROM sq.football_clubs WHERE league_id = $1`,
    [leagueId]
  );
  const clubIdByTeamApiId = new Map(clubsResult.rows.map((row) => [row.api_football_team_id, row.id]));

  const initialResponse = await fetch(`${base}/players?league=${premierLeagueApiId}&season=${season}&page=1`, {
    headers: {
      'x-apisports-key': apiKey,
      Accept: 'application/json',
    },
  });

  if (!initialResponse.ok) {
    throw new Error(`Failed probing Premier League bulk players: ${initialResponse.status}`);
  }

  const initialData = await initialResponse.json();
  const totalPages = Number(initialData?.paging?.total || 1);
  let remainingDay = readHeaderNumber(initialResponse.headers, 'x-ratelimit-requests-remaining', 0);
  let remainingMinute = readHeaderNumber(initialResponse.headers, 'x-ratelimit-remaining', 0);

  summary.headers = {
    afterProbe: {
      remainingDay,
      remainingMinute,
      totalPages,
    },
  };

  for (let page = startPage; page <= totalPages; page += 1) {
    if (remainingDay <= 0) {
      summary.stoppedBecause = 'daily-limit-reached';
      break;
    }
    if (remainingMinute <= 0) {
      summary.stoppedBecause = 'minute-limit-reached';
      break;
    }

    summary.lastPageAttempted = page;
    const response = await fetch(`${base}/players?league=${premierLeagueApiId}&season=${season}&page=${page}`, {
      headers: {
        'x-apisports-key': apiKey,
        Accept: 'application/json',
      },
    });

    if (response.status === 429) {
      summary.stoppedBecause = 'provider-returned-429';
      break;
    }

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Premier League bulk fetch failed on page ${page}: ${response.status} ${errorText}`);
    }

    const data = await response.json();
    remainingDay = readHeaderNumber(response.headers, 'x-ratelimit-requests-remaining', remainingDay);
    remainingMinute = readHeaderNumber(response.headers, 'x-ratelimit-remaining', remainingMinute);
    summary.pagesFetched += 1;
    summary.headers.lastSeen = { remainingDay, remainingMinute };

    for (const row of data.response || []) {
      const player = row.player || {};
      const statistics = Array.isArray(row.statistics) ? row.statistics : [];
      const statistic = statistics.find((entry) => clubIdByTeamApiId.has(entry?.team?.id)) || statistics[0] || null;
      const teamApiId = statistic?.team?.id;
      const clubId = teamApiId ? clubIdByTeamApiId.get(teamApiId) : null;

      if (!player.id || !clubId) {
        summary.playersSkippedWithoutClub += 1;
        continue;
      }

      const positionLabel = statistic?.games?.position || player.position || null;
      const playerResult = await client.query(
        `
          INSERT INTO sq.football_players (
            api_football_player_id,
            club_id,
            league_id,
            name,
            first_name,
            last_name,
            nationality,
            age,
            position_label,
            starter_slot_code,
            photo_url,
            is_active,
            metadata,
            synced_at,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, TRUE, $12::jsonb, NOW(), NOW())
          ON CONFLICT (api_football_player_id)
          DO UPDATE SET
            club_id = EXCLUDED.club_id,
            league_id = EXCLUDED.league_id,
            name = EXCLUDED.name,
            first_name = EXCLUDED.first_name,
            last_name = EXCLUDED.last_name,
            nationality = EXCLUDED.nationality,
            age = EXCLUDED.age,
            position_label = EXCLUDED.position_label,
            starter_slot_code = EXCLUDED.starter_slot_code,
            photo_url = EXCLUDED.photo_url,
            is_active = TRUE,
            metadata = EXCLUDED.metadata,
            synced_at = NOW(),
            updated_at = NOW()
          RETURNING id
        `,
        [
          player.id,
          clubId,
          leagueId,
          player.name || [player.firstname, player.lastname].filter(Boolean).join(' ') || `Player ${player.id}`,
          player.firstname || null,
          player.lastname || null,
          player.nationality || null,
          player.age || null,
          positionLabel,
          mapPositionToSlot(positionLabel),
          player.photo || null,
          JSON.stringify({
            provider: 'api-football',
            providerPlayerId: player.id,
            providerPayload: player,
            statistics,
            sourceEndpoint: 'players',
            bulkEndpoint: true,
          }),
        ]
      );

      await client.query(
        `
          INSERT INTO sq.football_card_templates (
            player_id,
            card_type,
            rarity,
            season_year,
            image_url,
            metadata
          )
          VALUES ($1, 'base', 'common', $2, $3, $4::jsonb)
          ON CONFLICT (player_id, card_type, rarity, season_year)
          DO UPDATE SET
            image_url = EXCLUDED.image_url,
            metadata = EXCLUDED.metadata
        `,
        [
          playerResult.rows[0].id,
          season,
          player.photo || null,
          JSON.stringify({
            provider: 'api-football',
            autoSynced: true,
            sourceEndpoint: 'players',
            bulkEndpoint: true,
          }),
        ]
      );

      summary.playersUpserted += 1;
      summary.templatesUpserted += 1;
    }
  }

  if (!summary.stoppedBecause) {
    summary.stoppedBecause = 'all-pages-loaded';
  }

  const countResult = await client.query(
    `
      SELECT COUNT(*)::int AS player_count,
             COUNT(*) FILTER (WHERE COALESCE((metadata->>'bulkEndpoint')::boolean, FALSE) = TRUE)::int AS bulk_player_count
      FROM sq.football_players
      WHERE league_id = $1
    `,
    [leagueId]
  );
  summary.currentPremierLeagueCounts = countResult.rows[0];

  console.log(JSON.stringify(summary, null, 2));
} finally {
  client.release();
  await pool.end();
}