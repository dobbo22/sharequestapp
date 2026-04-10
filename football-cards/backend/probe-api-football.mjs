const apiKey = process.env.API_FOOTBALL_KEY;

if (!apiKey) {
  console.error('Missing API_FOOTBALL_KEY environment variable.');
  process.exit(1);
}

const baseUrl = process.env.API_FOOTBALL_BASE_URL || 'https://v3.football.api-sports.io';
const headers = {
  'x-apisports-key': apiKey,
};

const targetLeagues = [
  { id: 39, name: 'Premier League' },
  { id: 40, name: 'Championship' },
  { id: 41, name: 'League One' },
  { id: 42, name: 'League Two' },
];

async function apiGet(path) {
  const response = await fetch(baseUrl + path, { headers });
  const data = await response.json();

  return {
    status: response.status,
    remainingDay: response.headers.get('x-ratelimit-requests-remaining'),
    remainingMinute: response.headers.get('x-ratelimit-remaining'),
    data,
  };
}

async function main() {
  const status = await apiGet('/status');

  const teamCounts = [];
  for (const league of targetLeagues) {
    const teams = await apiGet(`/teams?league=${league.id}&season=2024`);
    teamCounts.push({
      name: league.name,
      leagueId: league.id,
      teamCount: teams.data?.results ?? 0,
      sampleTeamId: teams.data?.response?.[0]?.team?.id ?? null,
    });
  }

  const totalTeams = teamCounts.reduce((sum, league) => sum + league.teamCount, 0);

  const sampleTeamId = teamCounts[0]?.sampleTeamId;
  const sampleSquad = sampleTeamId ? await apiGet(`/players/squads?team=${sampleTeamId}`) : null;
  const samplePlayers = sampleTeamId ? await apiGet(`/players?team=${sampleTeamId}&season=2024&page=1`) : null;

  console.log(JSON.stringify({
    account: {
      http: status.status,
      plan: status.data?.response?.subscription?.plan,
      dailyLimit: status.data?.response?.requests?.limit_day,
      dailyUsed: status.data?.response?.requests?.current,
      remainingDayHeader: status.remainingDay,
      remainingMinuteHeader: status.remainingMinute,
    },
    fourLeagueTeamCounts: teamCounts,
    totalTeams,
    estimatedBootstrapRequests: {
      teamsPerLeague: targetLeagues.length,
      squadsPerTeam: totalTeams,
      roughTotal: targetLeagues.length + totalTeams,
    },
    sampleComparison: {
      squadResults: sampleSquad?.data?.results ?? null,
      squadPlayerCount: sampleSquad?.data?.response?.[0]?.players?.length ?? null,
      playersResultsPage1: samplePlayers?.data?.results ?? null,
      playersPaging: samplePlayers?.data?.paging ?? null,
    },
    supportedBulkPatterns: {
      fixturesIdsMax: 20,
      injuriesIdsMax: 20,
      trophiesPlayersMax: 20,
      sidelinedPlayersMax: 20,
      notes: 'Teams are one call per league-season. Squads are one call per team. Player statistics are paginated and significantly more expensive.'
    }
  }, null, 2));
}

main().catch((error) => {
  console.error('API-Football probe failed:', error);
  process.exit(1);
});