import { apiFootballGet } from './football/apiFootballClient.js';
import { sportmonksGet } from './football/sportmonksClient.js';
import { authenticate, isAdmin } from './football/auth.js';
import { getFootballPool } from './football/db.js';
import { getFootballGameConfig } from './football/gameConfig.js';

const SPORTMONKS_PROVIDER_OFFSET = 1000000000;

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

function slugify(value) {
  return String(value || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'league';
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

function parsePositiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return parsed;
}

function parseBoolean(value, fallback = false) {
  if (typeof value === 'boolean') {
    return value;
  }

  if (value === undefined || value === null || value === '') {
    return fallback;
  }

  const normalized = String(value).trim().toLowerCase();
  if (['true', '1', 'yes', 'on'].includes(normalized)) {
    return true;
  }
  if (['false', '0', 'no', 'off'].includes(normalized)) {
    return false;
  }

  return fallback;
}

function parseLimit(value, fallback = 10) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.min(parsed, 50);
}

function normalizeSyncSource(value, fallback = 'api-football') {
  if (typeof value !== 'string') {
    return fallback;
  }

  const normalized = value.trim().toLowerCase();
  return normalized === 'sportmonks' ? 'sportmonks' : 'api-football';
}

function toIsoOrNull(value) {
  if (!value) {
    return null;
  }

  try {
    return new Date(value).toISOString();
  } catch {
    return null;
  }
}

function toSafeDetails(value) {
  if (!value || typeof value !== 'object') {
    return {};
  }
  return value;
}

function providerScopedId(source, rawId) {
  const parsed = Number.parseInt(rawId, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return null;
  }

  return source === 'sportmonks' ? SPORTMONKS_PROVIDER_OFFSET + parsed : parsed;
}

function extractSeasonYears(value) {
  const matches = String(value || '').match(/\d{4}/g) || [];
  return matches.map((year) => Number.parseInt(year, 10)).filter(Number.isFinite);
}

function selectSportmonksSeason(seasons, targetSeason) {
  if (!Array.isArray(seasons) || seasons.length === 0) {
    return null;
  }

  const ranked = seasons.map((season, index) => {
    const years = extractSeasonYears(season?.name);
    let score = 0;
    if (season?.is_current === true) score += 100;
    if (years.includes(targetSeason)) score += 50;
    if (years.includes(targetSeason + 1)) score += 40;

    return {
      season,
      score,
      maxYear: years.length > 0 ? Math.max(...years) : -1,
      index,
    };
  });

  ranked.sort((left, right) => right.score - left.score || right.maxYear - left.maxYear || left.index - right.index);
  return ranked[0]?.season || null;
}

function deriveSeasonYear(value, fallbackYear) {
  const years = extractSeasonYears(value?.name);
  if (years.length > 0) {
    return Math.min(...years);
  }

  const startingAt = typeof value?.starting_at === 'string' ? value.starting_at : null;
  if (startingAt && /^\d{4}-\d{2}-\d{2}/.test(startingAt)) {
    const parsed = Number.parseInt(startingAt.slice(0, 4), 10);
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed;
    }
  }

  return fallbackYear;
}

function getDefaultFootballSeasonYear(now = new Date()) {
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth();
  return month >= 6 ? year : year - 1;
}

function deriveAgeFromDateOfBirth(value) {
  if (!value) {
    return null;
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }

  const now = new Date();
  let age = now.getUTCFullYear() - date.getUTCFullYear();
  const monthDelta = now.getUTCMonth() - date.getUTCMonth();
  if (monthDelta < 0 || (monthDelta === 0 && now.getUTCDate() < date.getUTCDate())) {
    age -= 1;
  }

  return age > 0 ? age : null;
}

function mapJobRow(row) {
  const startedAt = toIsoOrNull(row.started_at);
  const completedAt = toIsoOrNull(row.completed_at);
  const details = toSafeDetails(row.details);

  let durationSeconds = null;
  if (startedAt && completedAt) {
    durationSeconds = Math.max(0, Math.round((Date.parse(completedAt) - Date.parse(startedAt)) / 1000));
  }

  return {
    id: row.id,
    source: row.source,
    jobType: row.job_type,
    status: row.status,
    startedAt,
    completedAt,
    durationSeconds,
    requestedByUserId: row.requested_by_user_id || null,
    createdAt: toIsoOrNull(row.created_at),
    details,
  };
}

async function createSyncJob(client, userId, jobType, source) {
  const result = await client.query(
    `
      INSERT INTO sq.football_sync_jobs (source, job_type, status, started_at, requested_by_user_id, details)
      VALUES ($1, $2, 'running', NOW(), $3, '{}'::jsonb)
      RETURNING id
    `,
    [source, jobType, userId]
  );

  return result.rows[0].id;
}

async function finishSyncJob(client, jobId, status, details) {
  await client.query(
    `
      UPDATE sq.football_sync_jobs
      SET status = $2,
          completed_at = NOW(),
          details = $3::jsonb
      WHERE id = $1
    `,
    [jobId, status, JSON.stringify(details)]
  );
}

function getLeaguePlayerSyncStrategy(configuredLeague, includePremierLeagueStats) {
  const tier = Number(configuredLeague?.tier);
  if (tier === 1 && !includePremierLeagueStats) {
    return 'squads';
  }

  return 'bulk';
}

function countRemainingBulkLeagues(leagues, startIndex, includePremierLeagueStats) {
  return leagues
    .slice(startIndex)
    .filter((league) => getLeaguePlayerSyncStrategy(league, includePremierLeagueStats) === 'bulk')
    .length;
}

function buildSquadPlayerRecord(player, source) {
  const playerApiId = player?.id;
  if (!playerApiId) {
    return null;
  }

  const positionLabel = player.position || null;
  return {
    playerApiId,
    name: player.name || [player.firstname, player.lastname].filter(Boolean).join(' ') || `Player ${playerApiId}`,
    firstName: player.firstname || null,
    lastName: player.lastname || null,
    nationality: player.nationality || null,
    age: player.age || null,
    positionLabel,
    starterSlotCode: mapPositionToSlot(positionLabel),
    photoUrl: player.photo || null,
    metadata: {
      provider: source,
      providerPlayerId: playerApiId,
      providerPayload: player,
      sourceEndpoint: 'players/squads',
    },
  };
}

function extractStatisticTotal(detail) {
  const value = detail?.value;
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  if (value && typeof value === 'object') {
    for (const key of ['total', 'minutes', 'goals', 'won', 'scored', 'successful']) {
      const candidate = value[key];
      if (typeof candidate === 'number' && Number.isFinite(candidate)) {
        return candidate;
      }
    }
  }

  return null;
}

function extractStatisticAverage(detail) {
  const value = detail?.value;
  if (!value || typeof value !== 'object') {
    return null;
  }

  const candidate = value.average;
  return typeof candidate === 'number' && Number.isFinite(candidate) ? candidate : null;
}

function extractStatisticMaximum(detail) {
  const value = detail?.value;
  if (!value || typeof value !== 'object') {
    return null;
  }

  const candidate = value.highest;
  return typeof candidate === 'number' && Number.isFinite(candidate) ? candidate : null;
}

function extractStatisticMinimum(detail) {
  const value = detail?.value;
  if (!value || typeof value !== 'object') {
    return null;
  }

  const candidate = value.lowest;
  return typeof candidate === 'number' && Number.isFinite(candidate) ? candidate : null;
}

function clampNumber(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function roundToSingleDecimal(value) {
  return Math.round(value * 10) / 10;
}

function inferRatingRole(starterSlotCode, positionLabel, detailedPositionLabel) {
  const slot = String(starterSlotCode || '').toUpperCase();
  const text = `${positionLabel || ''} ${detailedPositionLabel || ''}`.toLowerCase();

  if (slot === 'GK' || text.includes('goalkeeper')) {
    return 'goalkeeper';
  }

  if (['RB', 'LB', 'RCB', 'LCB'].includes(slot) || text.includes('back') || text.includes('defender')) {
    return 'defender';
  }

  if (['CM', 'RM', 'LM'].includes(slot) || text.includes('midfield')) {
    return 'midfielder';
  }

  if (slot === 'ST' || text.includes('wing') || text.includes('forward') || text.includes('attacker') || text.includes('striker')) {
    return 'attacker';
  }

  return 'midfielder';
}

function computeFallbackFootballScore(stats, role) {
  const appearances = stats?.appearances || 0;
  const goals = stats?.goals || 0;
  const assists = stats?.assists || 0;
  const tackles = stats?.tackles || 0;
  const passes = stats?.passes || 0;
  const shotsOnTarget = stats?.shotsOnTarget || 0;
  const cleanSheets = stats?.cleanSheets || 0;
  const interceptions = stats?.interceptions || 0;
  const keyPasses = stats?.keyPasses || 0;
  const yellowCards = stats?.yellowCards || 0;
  const redCards = stats?.redCards || 0;

  const appearanceFactor = clampNumber(appearances / 10, 0, 1);
  let score = 5.6;

  if (role === 'attacker') {
    score += Math.min(1.6, goals * 0.11 + assists * 0.08 + shotsOnTarget * 0.018);
  } else if (role === 'defender') {
    score += Math.min(1.5, tackles * 0.02 + interceptions * 0.025 + cleanSheets * 0.08 + assists * 0.04);
  } else if (role === 'goalkeeper') {
    score += Math.min(1.5, cleanSheets * 0.11 + passes * 0.0007 + appearances * 0.025);
  } else {
    score += Math.min(1.5, assists * 0.08 + keyPasses * 0.02 + passes * 0.0007 + tackles * 0.012 + goals * 0.06);
  }

  score -= Math.min(0.5, yellowCards * 0.03 + redCards * 0.18);
  score = 5.4 + ((score - 5.4) * appearanceFactor);

  return clampNumber(score, 4.5, 9.4);
}

function computeFallbackFootballRating(stats, role) {
  return roundToSingleDecimal(computeFallbackFootballScore(stats, role));
}

function computeRoleBasedRatingAdjustment(stats, role) {
  const goals = stats?.goals || 0;
  const assists = stats?.assists || 0;
  const tackles = stats?.tackles || 0;
  const interceptions = stats?.interceptions || 0;
  const keyPasses = stats?.keyPasses || 0;
  const shotsOnTarget = stats?.shotsOnTarget || 0;
  const passes = stats?.passes || 0;
  const cleanSheets = stats?.cleanSheets || 0;
  const yellowCards = stats?.yellowCards || 0;
  const redCards = stats?.redCards || 0;
  const minutes = stats?.minutes || 0;
  const appearances = stats?.appearances || 0;

  const per90Scale = minutes > 0 ? 90 / minutes : 0;
  const goalsPer90 = goals * per90Scale;
  const assistsPer90 = assists * per90Scale;
  const shotsOnTargetPer90 = shotsOnTarget * per90Scale;
  const tacklesPer90 = tackles * per90Scale;
  const interceptionsPer90 = interceptions * per90Scale;
  const keyPassesPer90 = keyPasses * per90Scale;
  const passesPer90 = passes * per90Scale;
  const cleanSheetsPerAppearance = appearances > 0 ? cleanSheets / appearances : 0;

  let adjustment = 0;

  if (role === 'attacker') {
    adjustment += Math.min(0.45, goalsPer90 * 0.9 + assistsPer90 * 0.45 + shotsOnTargetPer90 * 0.12 + keyPassesPer90 * 0.08);
  } else if (role === 'defender') {
    adjustment += Math.min(0.4, tacklesPer90 * 0.18 + interceptionsPer90 * 0.2 + cleanSheetsPerAppearance * 0.55 + assistsPer90 * 0.18);
  } else if (role === 'goalkeeper') {
    adjustment += Math.min(0.35, cleanSheetsPerAppearance * 0.7 + passesPer90 * 0.003);
  } else {
    adjustment += Math.min(0.42, assistsPer90 * 0.45 + keyPassesPer90 * 0.14 + passesPer90 * 0.002 + tacklesPer90 * 0.06 + goalsPer90 * 0.4);
  }

  adjustment -= Math.min(0.25, yellowCards * 0.01 + redCards * 0.12);
  return roundToSingleDecimal(clampNumber(adjustment, -0.4, 0.5));
}

function deriveFootballRatingTier(rating) {
  if (!Number.isFinite(rating)) {
    return 'standard';
  }

  if (rating >= 7.78) return 'elite';
  if (rating >= 7.42) return 'gold';
  if (rating >= 7.0) return 'silver';
  if (rating >= 6.2) return 'bronze';
  return 'standard';
}

function computeAgePotentialAdjustment(age) {
  if (!Number.isFinite(age)) {
    return 0;
  }

  if (age <= 19) return 0.35;
  if (age <= 21) return 0.3;
  if (age <= 24) return 0.18;
  if (age <= 29) return 0.08;
  if (age <= 32) return 0;
  if (age <= 35) return -0.08;
  return -0.15;
}

function buildBasicProfileRatingSummary(starterSlotCode, positionLabel, detailedPositionLabel, age) {
  const role = inferRatingRole(starterSlotCode, positionLabel, detailedPositionLabel);
  const roleBaseByType = {
    goalkeeper: 5.5,
    defender: 5.6,
    midfielder: 5.7,
    attacker: 5.8,
  };

  const baseScore = roleBaseByType[role] ?? 5.6;
  const potentialAdjustment = computeAgePotentialAdjustment(age);
  const score = clampNumber(baseScore + potentialAdjustment, 5.2, 6.1);

  return {
    overall: roundToSingleDecimal(score),
    source: 'fallback-basic-profile',
    confidence: 0.2,
    role,
    tier: 'unscouted',
    baseAverage: null,
    roleAdjustment: 0,
    appearances: 0,
  };
}

function buildFootballRatingSummary(stats, starterSlotCode, positionLabel, detailedPositionLabel, age) {
  if (!stats) {
    return buildBasicProfileRatingSummary(starterSlotCode, positionLabel, detailedPositionLabel, age);
  }

  const role = inferRatingRole(starterSlotCode, positionLabel, detailedPositionLabel);
  const appearances = stats.appearances || 0;
  const ratingAverage = stats.ratingAverage;
  const roleAdjustment = computeRoleBasedRatingAdjustment(stats, role);

  if (typeof ratingAverage === 'number' && Number.isFinite(ratingAverage)) {
    const confidence = clampNumber(Math.max(appearances, 1) / 10, 0.35, 1);
    const neutral = role === 'goalkeeper' ? 6.2 : 6.0;
    const stabilized = neutral + ((ratingAverage - neutral) * confidence) + roleAdjustment;
    const tierScore = clampNumber(stabilized, 4.5, 9.9);
    const overall = roundToSingleDecimal(tierScore);

    return {
      overall,
      source: 'sportmonks-rating-average',
      confidence: roundToSingleDecimal(confidence),
      role,
      tier: deriveFootballRatingTier(tierScore),
      baseAverage: roundToSingleDecimal(ratingAverage),
      roleAdjustment,
      appearances,
    };
  }

  const fallbackScore = computeFallbackFootballScore(stats, role);
  const overall = roundToSingleDecimal(fallbackScore);

  return {
    overall,
    source: 'fallback-curated-stats',
    confidence: roundToSingleDecimal(clampNumber(Math.max(appearances, 1) / 10, 0.3, 0.8)),
    role,
    tier: deriveFootballRatingTier(fallbackScore),
    baseAverage: null,
    roleAdjustment,
    appearances,
  };
}

function buildSportmonksStatSummary(statistics) {
  const seasonStatistic = Array.isArray(statistics)
    ? statistics.find((entry) => entry?.has_values && Array.isArray(entry?.details)) || statistics[0] || null
    : null;

  const details = Array.isArray(seasonStatistic?.details) ? seasonStatistic.details : [];
  const codeMap = new Map();

  for (const detail of details) {
    const code = detail?.type?.code;
    if (!code || codeMap.has(code)) {
      continue;
    }
    codeMap.set(code, detail);
  }

  const summary = {
    appearances: extractStatisticTotal(codeMap.get('appearances')),
    minutes: extractStatisticTotal(codeMap.get('minutes-played')),
    goals: extractStatisticTotal(codeMap.get('goals')),
    assists: extractStatisticTotal(codeMap.get('assists')),
    tackles: extractStatisticTotal(codeMap.get('tackles')),
    interceptions: extractStatisticTotal(codeMap.get('interceptions')),
    keyPasses: extractStatisticTotal(codeMap.get('key-passes')),
    passes: extractStatisticTotal(codeMap.get('passes')),
    saves: extractStatisticTotal(codeMap.get('saves')),
    shotsOnTarget: extractStatisticTotal(codeMap.get('shots-on-target')),
    shotsTotal: extractStatisticTotal(codeMap.get('shots-total')),
    cleanSheets: extractStatisticTotal(codeMap.get('cleansheets')),
    goalsConceded: extractStatisticTotal(codeMap.get('goals-conceded')),
    yellowCards: extractStatisticTotal(codeMap.get('yellowcards')),
    redCards: extractStatisticTotal(codeMap.get('redcards')),
    ratingAverage: extractStatisticAverage(codeMap.get('rating')),
    ratingHighest: extractStatisticMaximum(codeMap.get('rating')),
    ratingLowest: extractStatisticMinimum(codeMap.get('rating')),
  };

  const hasAnyValue = Object.values(summary).some((value) => typeof value === 'number' && Number.isFinite(value));
  if (!hasAnyValue) {
    return null;
  }

  return {
    ...summary,
    statCount: details.length,
    seasonId: seasonStatistic?.season_id || null,
    teamId: seasonStatistic?.team_id || null,
    jerseyNumber: seasonStatistic?.jersey_number || null,
  };
}

function buildTransferSummary(transfers) {
  const transferRows = Array.isArray(transfers) ? transfers : [];
  if (transferRows.length === 0) {
    return null;
  }

  const sorted = [...transferRows].sort((left, right) => {
    const leftValue = Date.parse(left?.date || '') || 0;
    const rightValue = Date.parse(right?.date || '') || 0;
    return rightValue - leftValue;
  });

  const latest = sorted[0] || null;
  const latestWithAmount = sorted.find((transfer) => typeof transfer?.amount === 'number' && Number.isFinite(transfer.amount)) || null;

  return {
    latestTransferDate: latest?.date || null,
    latestTransferAmount: latestWithAmount?.amount ?? null,
    transferCount: transferRows.length,
  };
}

function buildSportmonksSquadPlayerRecord(entry, source, clubId) {
  const player = entry?.player || {};
  const position = entry?.detailedposition || entry?.detailedPosition || entry?.position || {};
  const statistics = Array.isArray(player?.statistics) ? player.statistics : [];
  const transfers = Array.isArray(player?.transfers) ? player.transfers : [];
  const rawPlayerId = entry?.player_id || player.id;
  const playerApiId = providerScopedId(source, rawPlayerId);
  if (!playerApiId || !clubId) {
    return null;
  }

  const positionLabel = position.name || null;
  const starterSlotCode = mapPositionToSlot(positionLabel);
  const performanceStats = buildSportmonksStatSummary(statistics);
  const detailedPositionLabel = (entry?.detailedposition || entry?.detailedPosition || null)?.name || null;
  return {
    playerApiId,
    clubId,
    name: player.name || [player.firstname, player.lastname].filter(Boolean).join(' ') || `Player ${rawPlayerId}`,
    firstName: player.firstname || null,
    lastName: player.lastname || null,
    nationality: player.nationality || null,
    age: player.age || deriveAgeFromDateOfBirth(player.date_of_birth),
    positionLabel,
    starterSlotCode,
    photoUrl: player.image_path || player.photo || null,
    metadata: {
      provider: source,
      providerPlayerId: rawPlayerId,
      player,
      performanceStats,
      ratingSummary: buildFootballRatingSummary(performanceStats, starterSlotCode, positionLabel, detailedPositionLabel, player.age || deriveAgeFromDateOfBirth(player.date_of_birth)),
      transferSummary: buildTransferSummary(transfers),
      position: entry?.position || null,
      detailedPosition: entry?.detailedposition || entry?.detailedPosition || null,
      sourceEndpoint: 'squads/teams',
    },
  };
}

function pickBulkStatistic(statistics, clubIdByTeamApiId) {
  if (!Array.isArray(statistics) || statistics.length === 0) {
    return null;
  }

  return statistics.find((entry) => clubIdByTeamApiId.has(entry?.team?.id)) || statistics[0] || null;
}

function buildBulkPlayerRecord(row, source, clubIdByTeamApiId) {
  const player = row?.player || {};
  const playerApiId = player.id;
  if (!playerApiId) {
    return null;
  }

  const statistic = pickBulkStatistic(row.statistics, clubIdByTeamApiId);
  const teamApiId = statistic?.team?.id;
  const clubId = teamApiId ? clubIdByTeamApiId.get(teamApiId) : null;
  if (!clubId) {
    return null;
  }

  const positionLabel = statistic?.games?.position || player.position || null;
  return {
    playerApiId,
    clubId,
    name: player.name || [player.firstname, player.lastname].filter(Boolean).join(' ') || `Player ${playerApiId}`,
    firstName: player.firstname || null,
    lastName: player.lastname || null,
    nationality: player.nationality || null,
    age: player.age || null,
    positionLabel,
    starterSlotCode: mapPositionToSlot(positionLabel),
    photoUrl: player.photo || null,
    metadata: {
      provider: source,
      providerPlayerId: playerApiId,
      providerPayload: player,
      statistics: Array.isArray(row.statistics) ? row.statistics : [],
      sourceEndpoint: 'players',
      bulkEndpoint: true,
    },
  };
}

async function upsertPlayerAndTemplate(client, season, dbLeagueId, playerRecord) {
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
      playerRecord.playerApiId,
      playerRecord.clubId,
      dbLeagueId,
      playerRecord.name,
      playerRecord.firstName,
      playerRecord.lastName,
      playerRecord.nationality,
      playerRecord.age,
      playerRecord.positionLabel,
      playerRecord.starterSlotCode,
      playerRecord.photoUrl,
      JSON.stringify(playerRecord.metadata),
    ]
  );

  const dbPlayerId = playerResult.rows[0].id;

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
      dbPlayerId,
      season,
      playerRecord.photoUrl,
      JSON.stringify({
        provider: playerRecord.metadata.provider,
        autoSynced: true,
        sourceEndpoint: playerRecord.metadata.sourceEndpoint,
        bulkEndpoint: playerRecord.metadata.bulkEndpoint === true,
      }),
    ]
  );
}

async function syncTeamSquadPlayers(client, options) {
  const {
    providerGet,
    limitedTeams,
    clubIdByTeamApiId,
    dbLeagueId,
    season,
    source,
    summary,
    budgetRemaining,
  } = options;

  for (const teamEntry of limitedTeams) {
    const team = teamEntry.team || {};
    const teamApiId = team.id;
    const dbClubId = clubIdByTeamApiId.get(teamApiId);

    if (!teamApiId || !dbClubId) {
      continue;
    }

    if (budgetRemaining() < 1) {
      summary.teamsSkippedByBudget.push(team.name || String(teamApiId));
      continue;
    }

    let squadRows = [];
    try {
      const squadResult = await providerGet('/players/squads', { team: teamApiId });
      squadRows = Array.isArray(squadResult.data?.response?.[0]?.players)
        ? squadResult.data.response[0].players
        : [];
    } catch (error) {
      summary.warnings.push(`Squad fetch failed for team ${teamApiId}: ${error.message}`);
      continue;
    }

    for (const player of squadRows) {
      const playerRecord = buildSquadPlayerRecord(player, source);
      if (!playerRecord) {
        continue;
      }

      playerRecord.clubId = dbClubId;
      await upsertPlayerAndTemplate(client, season, dbLeagueId, playerRecord);
      summary.playersUpserted += 1;
      summary.templatesUpserted += 1;
    }
  }
}

async function syncLeagueBulkPlayers(client, options) {
  const {
    providerGet,
    leagueApiId,
    leagueName,
    clubIdByTeamApiId,
    dbLeagueId,
    season,
    source,
    summary,
    budgetRemaining,
    pageCap,
  } = options;

  let currentPage = 1;
  let totalPages = 1;
  let pagesFetched = 0;

  while (currentPage <= totalPages) {
    if (budgetRemaining() < 1) {
      summary.warnings.push(`Bulk player sync stopped for ${leagueName}: request budget exhausted`);
      break;
    }

    if (pageCap > 0 && pagesFetched >= pageCap) {
      summary.warnings.push(`Bulk player sync trimmed for ${leagueName} to ${pagesFetched}/${totalPages} pages to protect quota`);
      break;
    }

    let playersResult;
    try {
      playersResult = await providerGet('/players', {
        league: leagueApiId,
        season,
        page: currentPage,
      });
    } catch (error) {
      summary.warnings.push(`Bulk player fetch failed for ${leagueName} page ${currentPage}: ${error.message}`);
      break;
    }

    totalPages = parsePositiveInteger(playersResult.data?.paging?.total, currentPage);
    const playerRows = Array.isArray(playersResult.data?.response) ? playersResult.data.response : [];
    pagesFetched += 1;

    for (const row of playerRows) {
      const playerRecord = buildBulkPlayerRecord(row, source, clubIdByTeamApiId);
      if (!playerRecord) {
        summary.playersSkippedWithoutClub += 1;
        continue;
      }

      await upsertPlayerAndTemplate(client, season, dbLeagueId, playerRecord);
      summary.playersUpserted += 1;
      summary.templatesUpserted += 1;
    }

    currentPage += 1;
  }

  summary.bulkPlayerPagesFetched[leagueName] = pagesFetched;
}

async function syncSportmonksLeague(client, options) {
  const {
    providerGet,
    configuredLeague,
    resolvedLeagueId,
    season,
    source,
    summary,
    maxTeamsPerLeague,
    country,
  } = options;

  const providerLeagueId = resolvedLeagueId || configuredLeague?.sportmonksLeagueId;
  if (!providerLeagueId) {
    summary.warnings.push(`Missing sportmonksLeagueId for ${configuredLeague?.name || 'unknown league'}`);
    return;
  }

  const leagueDetailResult = await providerGet(`/leagues/${providerLeagueId}`, { include: 'seasons' });
  const leagueData = leagueDetailResult.data?.data || {};
  const selectedSeason = selectSportmonksSeason(leagueData.seasons, season);
  if (!selectedSeason?.id) {
    summary.warnings.push(`No Sportmonks season available for ${configuredLeague.name}`);
    return;
  }
  const resolvedSeasonYear = deriveSeasonYear(selectedSeason, season);

  const dbLeagueProviderId = providerScopedId(source, providerLeagueId);
  const leagueResult = await client.query(
    `
      INSERT INTO sq.football_leagues (
        api_football_league_id,
        season_year,
        name,
        slug,
        country,
        tier,
        logo_url,
        metadata,
        updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, NOW())
      ON CONFLICT (api_football_league_id, season_year)
      DO UPDATE SET
        name = EXCLUDED.name,
        slug = EXCLUDED.slug,
        country = EXCLUDED.country,
        tier = EXCLUDED.tier,
        logo_url = EXCLUDED.logo_url,
        metadata = EXCLUDED.metadata,
        is_active = TRUE,
        updated_at = NOW()
      RETURNING id
    `,
    [
      dbLeagueProviderId,
      resolvedSeasonYear,
      configuredLeague.name,
      slugify(configuredLeague.name),
      country,
      configuredLeague.tier || null,
      leagueData.image_path || null,
      JSON.stringify({
        provider: source,
        providerLeagueId,
        resolvedSeasonYear,
        selectedSeasonId: selectedSeason.id,
        selectedSeason,
        providerPayload: leagueData,
      }),
    ]
  );

  const dbLeagueId = leagueResult.rows[0].id;
  summary.leaguesProcessed += 1;

  const standingsResult = await providerGet(`/standings/seasons/${selectedSeason.id}`, { include: 'participant' });
  const standingsRows = Array.isArray(standingsResult.data?.data) ? standingsResult.data.data : [];
  const limitedTeams = standingsRows.slice(0, maxTeamsPerLeague);
  const clubIdByTeamApiId = new Map();

  if (standingsRows.length > maxTeamsPerLeague) {
    summary.warnings.push(
      `League ${configuredLeague.name} trimmed to ${maxTeamsPerLeague}/${standingsRows.length} teams to protect quota`
    );
  }

  for (const row of limitedTeams) {
    const participant = row?.participant || {};
    const rawTeamId = participant.id;
    const dbTeamProviderId = providerScopedId(source, rawTeamId);
    if (!dbTeamProviderId) {
      continue;
    }

    const clubResult = await client.query(
      `
        INSERT INTO sq.football_clubs (
          api_football_team_id,
          league_id,
          name,
          short_name,
          code,
          country,
          founded,
          logo_url,
          venue_name,
          venue_city,
          metadata,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, NOW())
        ON CONFLICT (api_football_team_id)
        DO UPDATE SET
          league_id = EXCLUDED.league_id,
          name = EXCLUDED.name,
          short_name = EXCLUDED.short_name,
          code = EXCLUDED.code,
          country = EXCLUDED.country,
          founded = EXCLUDED.founded,
          logo_url = EXCLUDED.logo_url,
          venue_name = EXCLUDED.venue_name,
          venue_city = EXCLUDED.venue_city,
          metadata = EXCLUDED.metadata,
          updated_at = NOW()
        RETURNING id
      `,
      [
        dbTeamProviderId,
        dbLeagueId,
        participant.name || `Team ${rawTeamId}`,
        participant.short_name || participant.name || null,
        participant.short_code || null,
        country,
        participant.founded || null,
        participant.image_path || null,
        null,
        null,
        JSON.stringify({
          provider: source,
          providerTeamId: rawTeamId,
          standingsRow: row,
          participant,
        }),
      ]
    );

    summary.clubsUpserted += 1;
    clubIdByTeamApiId.set(rawTeamId, clubResult.rows[0].id);
  }

  summary.playerSyncStrategies[configuredLeague.name] = 'sportmonks-squads';

  for (const row of limitedTeams) {
    const participant = row?.participant || {};
    const teamId = participant.id;
    const clubId = clubIdByTeamApiId.get(teamId);
    if (!teamId || !clubId) {
      continue;
    }

    let squadResult;
    try {
      squadResult = await providerGet(`/squads/teams/${teamId}`, {
        include: 'player.statistics.details.type;player.transfers;position;detailedPosition',
        filters: `playerstatisticSeasons:${selectedSeason.id}`,
      });
    } catch (error) {
      summary.warnings.push(`Sportmonks squad fetch failed for team ${teamId}: ${error.message}`);
      continue;
    }

    const squadRows = Array.isArray(squadResult.data?.data) ? squadResult.data.data : [];
    for (const squadEntry of squadRows) {
      const playerRecord = buildSportmonksSquadPlayerRecord(squadEntry, source, clubId);
      if (!playerRecord) {
        summary.playersSkippedWithoutClub += 1;
        continue;
      }

      await upsertPlayerAndTemplate(client, resolvedSeasonYear, dbLeagueId, playerRecord);
      summary.playersUpserted += 1;
      summary.templatesUpserted += 1;
    }
  }
}

async function handleSync(req, res, auth) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const season = parsePositiveInteger(req.body?.season, getDefaultFootballSeasonYear());
  const requestBudget = Math.min(parsePositiveInteger(req.body?.maxRequests, 95), 150);
  const maxTeamsPerLeague = Math.min(parsePositiveInteger(req.body?.maxTeamsPerLeague, 30), 40);
  const includePremierLeagueStats = parseBoolean(req.body?.includePremierLeagueStats, false);
  const maxBulkPlayerPagesPerLeague = parsePositiveInteger(req.body?.maxBulkPlayerPagesPerLeague, 0);
  const pool = getFootballPool();

  const summary = {
    source: 'api-football',
    season,
    requestBudget,
    includePremierLeagueStats,
    maxBulkPlayerPagesPerLeague,
    requestsUsed: 0,
    leaguesProcessed: 0,
    clubsUpserted: 0,
    playersUpserted: 0,
    templatesUpserted: 0,
    playersSkippedWithoutClub: 0,
    leaguesSkippedByBudget: [],
    teamsSkippedByBudget: [],
    playerSyncStrategies: {},
    bulkPlayerPagesFetched: {},
    warnings: [],
  };

  function budgetRemaining() {
    return requestBudget - summary.requestsUsed;
  }

  const client = await pool.connect();
  let syncJobId = null;

  try {
    const config = await getFootballGameConfig();
    const source = normalizeSyncSource(req.body?.source, config?.provider?.active || 'api-football');
    summary.source = source;
    const configuredLeagues = Array.isArray(config.sourceLeagues) ? config.sourceLeagues : [];
    const country = config.country || 'England';
    let sportmonksLeagueLookup = null;

    async function providerGet(path, params) {
      if (budgetRemaining() <= 0) {
        throw new Error('Request budget exhausted');
      }

      const result = source === 'sportmonks'
        ? await sportmonksGet(path, params)
        : await apiFootballGet(path, params);
      summary.requestsUsed += 1;
      return result;
    }

    if (source === 'sportmonks') {
      const leaguesResult = await providerGet('/leagues');
      const visibleLeagues = Array.isArray(leaguesResult.data?.data) ? leaguesResult.data.data : [];
      sportmonksLeagueLookup = {
        visibleIds: new Set(visibleLeagues.map((league) => league?.id).filter((value) => Number.isFinite(value))),
        byName: new Map(
          visibleLeagues.map((league) => [String(league?.name || '').toLowerCase().trim(), league]).filter(([name]) => name.length > 0)
        ),
      };
    }

    syncJobId = await createSyncJob(client, auth.userId, 'bootstrap-leagues-clubs-players', source);

    for (let leagueIndex = 0; leagueIndex < configuredLeagues.length; leagueIndex += 1) {
      const configuredLeague = configuredLeagues[leagueIndex];
      const leagueApiId = source === 'sportmonks'
        ? configuredLeague.sportmonksLeagueId
        : configuredLeague.apiFootballLeagueId;
      if (!leagueApiId) {
        summary.warnings.push(
          `Missing ${source === 'sportmonks' ? 'sportmonksLeagueId' : 'apiFootballLeagueId'} for ${configuredLeague.name}`
        );
        continue;
      }

      if (budgetRemaining() < 1) {
        summary.leaguesSkippedByBudget.push(configuredLeague.name);
        continue;
      }

      if (source === 'sportmonks') {
        const configuredSportmonksLeagueId = configuredLeague.sportmonksLeagueId;
        const discoveredLeague = sportmonksLeagueLookup?.byName.get(String(configuredLeague.name || '').toLowerCase().trim()) || null;
        const resolvedLeagueId = sportmonksLeagueLookup?.visibleIds.has(configuredSportmonksLeagueId)
          ? configuredSportmonksLeagueId
          : discoveredLeague?.id || null;

        if (!resolvedLeagueId) {
          summary.warnings.push(`Sportmonks league not accessible for ${configuredLeague.name}`);
          continue;
        }

        if (configuredSportmonksLeagueId && resolvedLeagueId !== configuredSportmonksLeagueId) {
          summary.warnings.push(
            `Sportmonks league ID fallback for ${configuredLeague.name}: using ${resolvedLeagueId} instead of configured ${configuredSportmonksLeagueId}`
          );
        }

        await syncSportmonksLeague(client, {
          providerGet,
          configuredLeague,
          resolvedLeagueId,
          season,
          source,
          summary,
          maxTeamsPerLeague,
          country,
        });
        continue;
      }

      const teamsResult = await providerGet('/teams', {
        league: leagueApiId,
        season,
      });

      const teamRows = Array.isArray(teamsResult.data?.response) ? teamsResult.data.response : [];

      const leagueResult = await client.query(
        `
          INSERT INTO sq.football_leagues (
            api_football_league_id,
            season_year,
            name,
            slug,
            country,
            tier,
            logo_url,
            metadata,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, NOW())
          ON CONFLICT (api_football_league_id, season_year)
          DO UPDATE SET
            name = EXCLUDED.name,
            slug = EXCLUDED.slug,
            country = EXCLUDED.country,
            tier = EXCLUDED.tier,
            logo_url = EXCLUDED.logo_url,
            metadata = EXCLUDED.metadata,
            is_active = TRUE,
            updated_at = NOW()
          RETURNING id
        `,
        [
          leagueApiId,
          season,
          configuredLeague.name,
          slugify(configuredLeague.name),
          country,
          configuredLeague.tier || null,
          teamRows[0]?.league?.logo || null,
          JSON.stringify({
            provider: source,
            providerLeagueId: leagueApiId,
            providerPayload: teamRows[0]?.league || null,
          }),
        ]
      );

      const dbLeagueId = leagueResult.rows[0].id;
      summary.leaguesProcessed += 1;

      const limitedTeams = teamRows.slice(0, maxTeamsPerLeague);
      const clubIdByTeamApiId = new Map();
      if (teamRows.length > maxTeamsPerLeague) {
        summary.warnings.push(
          `League ${configuredLeague.name} trimmed to ${maxTeamsPerLeague}/${teamRows.length} teams to protect quota`
        );
      }

      for (const teamEntry of limitedTeams) {
        const team = teamEntry.team || {};
        const venue = teamEntry.venue || {};
        const teamApiId = team.id;

        if (!teamApiId) {
          continue;
        }

        const clubResult = await client.query(
          `
            INSERT INTO sq.football_clubs (
              api_football_team_id,
              league_id,
              name,
              short_name,
              code,
              country,
              founded,
              logo_url,
              venue_name,
              venue_city,
              metadata,
              updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, NOW())
            ON CONFLICT (api_football_team_id)
            DO UPDATE SET
              league_id = EXCLUDED.league_id,
              name = EXCLUDED.name,
              short_name = EXCLUDED.short_name,
              code = EXCLUDED.code,
              country = EXCLUDED.country,
              founded = EXCLUDED.founded,
              logo_url = EXCLUDED.logo_url,
              venue_name = EXCLUDED.venue_name,
              venue_city = EXCLUDED.venue_city,
              metadata = EXCLUDED.metadata,
              updated_at = NOW()
            RETURNING id
          `,
          [
            teamApiId,
            dbLeagueId,
            team.name,
            team.name,
            team.code || null,
            team.country || country,
            team.founded || null,
            team.logo || null,
            venue.name || null,
            venue.city || null,
            JSON.stringify({ provider: source, team, venue }),
          ]
        );

        summary.clubsUpserted += 1;
        const dbClubId = clubResult.rows[0].id;
        clubIdByTeamApiId.set(teamApiId, dbClubId);
      }

      const playerSyncStrategy = getLeaguePlayerSyncStrategy(configuredLeague, includePremierLeagueStats);
      summary.playerSyncStrategies[configuredLeague.name] = playerSyncStrategy;

      if (playerSyncStrategy === 'squads') {
        await syncTeamSquadPlayers(client, {
          providerGet,
          limitedTeams,
          clubIdByTeamApiId,
          dbLeagueId,
          season,
          source,
          summary,
          budgetRemaining,
        });
        continue;
      }

      const remainingBulkLeagues = countRemainingBulkLeagues(
        configuredLeagues,
        leagueIndex,
        includePremierLeagueStats
      );
      const dynamicPageCap = Math.max(1, Math.floor(budgetRemaining() / Math.max(remainingBulkLeagues, 1)));
      const pageCap = maxBulkPlayerPagesPerLeague > 0 ? maxBulkPlayerPagesPerLeague : dynamicPageCap;

      await syncLeagueBulkPlayers(client, {
        providerGet,
        leagueApiId,
        leagueName: configuredLeague.name,
        clubIdByTeamApiId,
        dbLeagueId,
        season,
        source,
        summary,
        budgetRemaining,
        pageCap,
      });
    }

    const finalStatus = summary.leaguesProcessed > 0 ? 'completed' : 'failed';
    await finishSyncJob(client, syncJobId, finalStatus, summary);

    return res.status(finalStatus === 'completed' ? 200 : 500).json({
      success: finalStatus === 'completed',
      syncJobId,
      summary,
    });
  } catch (error) {
    console.error('POST /api/football/admin/sync failed', error);

    if (syncJobId) {
      try {
        const details = {
          ...summary,
          error: error.message,
        };
        await finishSyncJob(client, syncJobId, 'failed', details);
      } catch (jobError) {
        console.error('Failed updating sync job after error', jobError);
      }
    }

    return res.status(500).json({
      success: false,
      error: 'Football sync failed',
      details: error.message,
      summary,
    });
  } finally {
    client.release();
  }
}

async function handleSyncStatus(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET, OPTIONS');
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const pool = getFootballPool();
  const limit = parseLimit(req.query?.limit, 10);
  const source = typeof req.query?.source === 'string' && req.query.source.trim().length > 0
    ? req.query.source.trim()
    : null;
  const includeDetails = req.query?.includeDetails !== 'false';

  const client = await pool.connect();

  try {
    const whereClause = source ? 'WHERE source = $1' : '';
    const latestParams = source ? [source] : [];

    const latestResult = await client.query(
      `
        SELECT id, source, job_type, status, started_at, completed_at, requested_by_user_id, details, created_at
        FROM sq.football_sync_jobs
        ${whereClause}
        ORDER BY created_at DESC
        LIMIT 1
      `,
      latestParams
    );

    const listParams = source ? [source, limit] : [limit];
    const listQuery = source
      ? `
          SELECT id, source, job_type, status, started_at, completed_at, requested_by_user_id, details, created_at
          FROM sq.football_sync_jobs
          WHERE source = $1
          ORDER BY created_at DESC
          LIMIT $2
        `
      : `
          SELECT id, source, job_type, status, started_at, completed_at, requested_by_user_id, details, created_at
          FROM sq.football_sync_jobs
          ORDER BY created_at DESC
          LIMIT $1
        `;

    const listResult = await client.query(listQuery, listParams);

    const aggregateParams = source ? [source] : [];
    const aggregateQuery = source
      ? `
          SELECT
            COUNT(*)::INT AS total_runs,
            COUNT(*) FILTER (WHERE status = 'completed')::INT AS completed_runs,
            COUNT(*) FILTER (WHERE status = 'failed')::INT AS failed_runs,
            COUNT(*) FILTER (WHERE status = 'running')::INT AS running_runs,
            MAX(created_at) AS last_run_at
          FROM sq.football_sync_jobs
          WHERE source = $1
        `
      : `
          SELECT
            COUNT(*)::INT AS total_runs,
            COUNT(*) FILTER (WHERE status = 'completed')::INT AS completed_runs,
            COUNT(*) FILTER (WHERE status = 'failed')::INT AS failed_runs,
            COUNT(*) FILTER (WHERE status = 'running')::INT AS running_runs,
            MAX(created_at) AS last_run_at
          FROM sq.football_sync_jobs
        `;

    const aggregateResult = await client.query(aggregateQuery, aggregateParams);

    const latest = latestResult.rows[0] ? mapJobRow(latestResult.rows[0]) : null;
    const jobs = listResult.rows.map(mapJobRow).map((job) => {
      if (includeDetails) {
        return job;
      }

      return {
        ...job,
        details: undefined,
      };
    });

    const aggregateRow = aggregateResult.rows[0] || {};

    return res.status(200).json({
      success: true,
      data: {
        latest: includeDetails ? latest : latest ? { ...latest, details: undefined } : null,
        recent: jobs,
        aggregates: {
          totalRuns: aggregateRow.total_runs || 0,
          completedRuns: aggregateRow.completed_runs || 0,
          failedRuns: aggregateRow.failed_runs || 0,
          runningRuns: aggregateRow.running_runs || 0,
          lastRunAt: toIsoOrNull(aggregateRow.last_run_at),
        },
        filters: {
          source,
          limit,
          includeDetails,
        },
      },
    });
  } catch (error) {
    console.error('GET /api/football/admin/sync-status failed', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to load football sync status',
      details: error.message,
    });
  } finally {
    client.release();
  }
}

export async function handleFootballAdmin(req, res, action) {
  setCors(res);

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const auth = await authenticate(req);
  if (!auth || !isAdmin(auth)) {
    return res.status(403).json({ success: false, error: 'Admin access required' });
  }

  switch (action) {
    case 'sync':
      return handleSync(req, res, auth);
    case 'sync-status':
      return handleSyncStatus(req, res);
    default:
      return res.status(404).json({ success: false, error: 'Not found' });
  }
}