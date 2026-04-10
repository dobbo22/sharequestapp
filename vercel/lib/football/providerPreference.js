import { getFootballGameConfig } from './gameConfig.js';

export const SPORTMONKS_PROVIDER_OFFSET = 1000000000;

function normalizeProvider(provider) {
  return provider === 'sportmonks' ? 'sportmonks' : 'api-football';
}

function getStoredLeagueId(league, provider) {
  if (!league) {
    return null;
  }

  if (provider === 'sportmonks') {
    const leagueId = Number(league.sportmonksLeagueId);
    return Number.isFinite(leagueId) ? SPORTMONKS_PROVIDER_OFFSET + leagueId : null;
  }

  const leagueId = Number(league.apiFootballLeagueId);
  return Number.isFinite(leagueId) ? leagueId : null;
}

function collectLeagueIds(leagues, provider) {
  return leagues.map((league) => getStoredLeagueId(league, provider)).filter((leagueId) => Number.isFinite(leagueId));
}

export async function getFootballProviderPreference() {
  const config = await getFootballGameConfig();
  const preferredProvider = normalizeProvider(config?.provider?.active);
  const fallbackProvider = normalizeProvider(
    config?.provider?.fallback === preferredProvider ? (preferredProvider === 'sportmonks' ? 'api-football' : 'sportmonks') : config?.provider?.fallback
  );
  const sourceLeagues = Array.isArray(config?.sourceLeagues) ? config.sourceLeagues : [];

  return {
    config,
    preferredProvider,
    fallbackProvider,
    preferredLeagueIds: collectLeagueIds(sourceLeagues, preferredProvider),
    fallbackLeagueIds: collectLeagueIds(sourceLeagues, fallbackProvider),
  };
}