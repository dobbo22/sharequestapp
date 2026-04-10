const apiBaseUrl = process.env.API_FOOTBALL_BASE_URL || 'https://v3.football.api-sports.io';

function getApiKey() {
  return process.env.API_FOOTBALL_KEY;
}

function toQueryString(params = {}) {
  const entries = Object.entries(params).filter(([, value]) => value !== undefined && value !== null && value !== '');
  if (entries.length === 0) {
    return '';
  }

  const query = new URLSearchParams();
  for (const [key, value] of entries) {
    query.set(key, String(value));
  }

  return `?${query.toString()}`;
}

export async function apiFootballGet(path, params = {}) {
  const apiKey = getApiKey();
  if (!apiKey) {
    throw new Error('Missing API_FOOTBALL_KEY environment variable');
  }

  const response = await fetch(`${apiBaseUrl}${path}${toQueryString(params)}`, {
    headers: {
      'x-apisports-key': apiKey,
      Accept: 'application/json',
    },
  });

  const data = await response.json();

  if (!response.ok) {
    const providerMessage = data?.errors || data?.message || 'Unknown API-Football error';
    throw new Error(`API-Football request failed (${response.status}): ${JSON.stringify(providerMessage)}`);
  }

  return {
    status: response.status,
    headers: {
      remainingDay: response.headers.get('x-ratelimit-requests-remaining'),
      remainingMinute: response.headers.get('x-ratelimit-remaining'),
    },
    data,
  };
}