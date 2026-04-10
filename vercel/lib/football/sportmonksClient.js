const sportmonksBaseUrl = process.env.SPORTMONKS_BASE_URL || 'https://api.sportmonks.com/v3/football';

function getSportmonksToken() {
  return process.env.SPORTMONKS_TOKEN;
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

export async function sportmonksGet(path, params = {}) {
  const token = getSportmonksToken();
  if (!token) {
    throw new Error('Missing SPORTMONKS_TOKEN environment variable');
  }

  const response = await fetch(`${sportmonksBaseUrl}${path}${toQueryString(params)}`, {
    headers: {
      Authorization: token,
      Accept: 'application/json',
    },
  });

  const data = await response.json();

  if (!response.ok) {
    const providerMessage = data?.message || data?.error || data?.errors || 'Unknown Sportmonks error';
    throw new Error(`Sportmonks request failed (${response.status}): ${JSON.stringify(providerMessage)}`);
  }

  const rateLimit = data?.rate_limit || null;

  return {
    status: response.status,
    headers: {
      remaining: rateLimit?.remaining ?? null,
      resetsInSeconds: rateLimit?.resets_in_seconds ?? null,
      requestedEntity: rateLimit?.requested_entity ?? null,
    },
    data,
  };
}