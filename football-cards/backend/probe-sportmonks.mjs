import fs from 'node:fs/promises';
import path from 'node:path';

const token = process.env.SPORTMONKS_TOKEN;

if (!token) {
  console.error('Missing SPORTMONKS_TOKEN environment variable.');
  process.exit(1);
}

const baseUrl = process.env.SPORTMONKS_BASE_URL || 'https://api.sportmonks.com/v3/football';
const headers = {
  Authorization: token,
  Accept: 'application/json',
};

const gameConfigPath = path.resolve(process.cwd(), 'football-cards/backend/game-config.json');

async function apiGet(endpoint) {
  const response = await fetch(baseUrl + endpoint, { headers });
  const text = await response.text();
  let data;

  try {
    data = JSON.parse(text);
  } catch {
    data = { raw: text };
  }

  return {
    status: response.status,
    data,
  };
}

function normalizeByName(items) {
  return new Map(items.map((item) => [String(item.name || '').toLowerCase().trim(), item]));
}

async function loadConfig() {
  const raw = await fs.readFile(gameConfigPath, 'utf-8');
  return JSON.parse(raw);
}

async function main() {
  const config = await loadConfig();
  const targetLeagues = config.sourceLeagues || [];

  const leagues = await apiGet('/leagues');
  const leagueList = leagues.data?.data || [];
  const byName = normalizeByName(leagueList);

  const coverage = [];
  for (const target of targetLeagues) {
    const configuredId = target.sportmonksLeagueId ?? null;
    const foundByName = byName.get(String(target.name || '').toLowerCase().trim()) || null;
    const accessible = configuredId
      ? leagueList.some((league) => league.id === configuredId)
      : Boolean(foundByName);

    coverage.push({
      name: target.name,
      tier: target.tier,
      configuredSportmonksLeagueId: configuredId,
      accessible,
      discoveredLeagueId: foundByName?.id ?? null,
      discoveredCountryId: foundByName?.country_id ?? null,
    });
  }

  const firstAccessible = coverage.find((item) => item.accessible && item.configuredSportmonksLeagueId);

  let seasonProbe = null;
  let standingsProbe = null;
  let teamProbe = null;
  let squadProbe = null;

  if (firstAccessible) {
    const leagueDetail = await apiGet(`/leagues/${firstAccessible.configuredSportmonksLeagueId}?include=seasons`);
    const seasons = leagueDetail.data?.data?.seasons || [];
    const currentSeason = seasons.find((season) => season.is_current) || seasons[0] || null;

    seasonProbe = {
      leagueId: firstAccessible.configuredSportmonksLeagueId,
      seasonsCount: seasons.length,
      chosenSeasonId: currentSeason?.id ?? null,
      chosenSeasonName: currentSeason?.name ?? null,
    };

    if (currentSeason?.id) {
      const standings = await apiGet(`/standings/seasons/${currentSeason.id}?include=participant`);
      const rows = standings.data?.data || [];
      const firstParticipant = rows[0]?.participant || null;

      standingsProbe = {
        status: standings.status,
        rowCount: rows.length,
        sampleParticipantId: firstParticipant?.id ?? null,
        sampleParticipantName: firstParticipant?.name ?? null,
      };

      if (firstParticipant?.id) {
        teamProbe = await apiGet(`/teams/${firstParticipant.id}`);
        squadProbe = await apiGet(`/squads/teams/${firstParticipant.id}?include=player;position;detailedPosition`);
      }
    }
  }

  const sampleSquadEntry = squadProbe?.data?.data?.[0] || null;

  console.log(JSON.stringify({
    account: {
      leagueCountVisible: leagueList.length,
      subscription: leagues.data?.subscription ?? null,
      rateLimit: leagues.data?.rate_limit ?? null,
    },
    coverage,
    firstAccessibleSyncPath: {
      seasonProbe,
      standingsProbe,
      teamStatus: teamProbe?.status ?? null,
      squadStatus: squadProbe?.status ?? null,
      squadCount: squadProbe?.data?.data?.length ?? null,
      squadEntryKeys: sampleSquadEntry ? Object.keys(sampleSquadEntry) : null,
      nestedPlayerKeys: sampleSquadEntry?.player ? Object.keys(sampleSquadEntry.player) : null,
      nestedPositionKeys: sampleSquadEntry?.position ? Object.keys(sampleSquadEntry.position) : null,
      nestedDetailedPositionKeys: sampleSquadEntry?.detailedposition ? Object.keys(sampleSquadEntry.detailedposition) : null,
    },
  }, null, 2));
}

main().catch((error) => {
  console.error('Sportmonks probe failed:', error);
  process.exit(1);
});
