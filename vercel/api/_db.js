import { Pool } from 'pg';

export function getPool() {
  // Reuse pool across warm function invocations to avoid exhausting Neon connections
  if (global._pgPool) return global._pgPool;

  // Prefer an API-specific connection string so we can set a limited-role DB for serverless
  // without overwriting the website's `DATABASE_URL`.
  const connectionString = process.env.API_DATABASE_URL || process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error('DATABASE_URL or API_DATABASE_URL is not set in environment');
  }

  const maxClients = parseInt(process.env.PG_MAX_CLIENTS || '5', 10);

  const config = {
    connectionString,
    max: maxClients,
    idleTimeoutMillis: 30000,
  };

  // For Neon TLS (sslmode=require) ensure ssl option when running in production
  if (process.env.NODE_ENV === 'production' || process.env.NEON_REQUIRE_SSL === '1') {
    config.ssl = {
      rejectUnauthorized: false,
    };
  }

  const pool = new Pool(config);
  // set search_path so unqualified table names resolve to schema 'sq' first
  pool.on('connect', async (client) => {
    try {
      await client.query("SET search_path TO sq, public");
    } catch (err) {
      console.error('Failed to set search_path for client', err);
    }
  });

  global._pgPool = pool;
  return pool;
}
