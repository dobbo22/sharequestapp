import { Pool } from 'pg';

function normalizeConnectionString(rawConnectionString) {
  try {
    const connectionUrl = new URL(rawConnectionString);
    const sslMode = connectionUrl.searchParams.get('sslmode');
    if (sslMode === 'require' || sslMode === 'prefer' || sslMode === 'verify-ca') {
      connectionUrl.searchParams.set('sslmode', 'verify-full');
    }
    return connectionUrl.toString();
  } catch {
    return rawConnectionString;
  }
}

export function getPool() {
  if (global._pgPool) return global._pgPool;

  const connectionString = normalizeConnectionString(process.env.API_DATABASE_URL || process.env.DATABASE_URL);
  if (!connectionString) {
    throw new Error('DATABASE_URL or API_DATABASE_URL is not set in environment');
  }

  const maxClients = parseInt(process.env.PG_MAX_CLIENTS || '5', 10);
  const config = {
    connectionString,
    max: maxClients,
    idleTimeoutMillis: 30000,
  };

  const pool = new Pool(config);

  global._pgPool = pool;
  return pool;
}