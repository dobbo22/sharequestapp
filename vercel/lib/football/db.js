import { Pool } from 'pg';

let warnedAboutFallback = false;

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

export function getFootballPool() {
  if (global._footballPgPool) return global._footballPgPool;

  const connectionString = normalizeConnectionString(
    process.env.FOOTBALL_DATABASE_URL || process.env.API_DATABASE_URL || process.env.DATABASE_URL
  );
  if (!connectionString) {
    throw new Error('FOOTBALL_DATABASE_URL or API_DATABASE_URL or DATABASE_URL is not set in environment');
  }

  if (!process.env.FOOTBALL_DATABASE_URL && !warnedAboutFallback) {
    warnedAboutFallback = true;
    console.warn('FOOTBALL_DATABASE_URL is not configured; football routes are falling back to the shared API database.');
  }

  const pool = new Pool({
    connectionString,
    max: parseInt(process.env.FOOTBALL_PG_MAX_CLIENTS || process.env.PG_MAX_CLIENTS || '5', 10),
    idleTimeoutMillis: 30000,
  });

  global._footballPgPool = pool;
  return pool;
}