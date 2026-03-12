#!/usr/bin/env node
import { readFile } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import pkg from 'pg';
const { Pool } = pkg;

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function run() {
  const conn = process.env.API_DATABASE_URL || process.env.DATABASE_URL;
  if (!conn) {
    console.error('ERROR: API_DATABASE_URL or DATABASE_URL must be set');
    process.exit(1);
  }
  console.log('Using connection:', conn.replace(/:(.*)@/, ':<REDACTED>@'));
  const pool = new Pool({ connectionString: conn, ssl: { rejectUnauthorized: false } });
  const client = await pool.connect();
  try {
    const migrationsDir = path.join(__dirname, '..', 'migrations');
    const files = ['001_create_users.sql','002_create_api_tokens.sql','003_create_items.sql','004_create_sq_schema_and_tables.sql','005_add_hash_algo_to_sq_api_tokens.sql'];
    for (const f of files) {
      const p = path.join(migrationsDir, f);
      console.log('\n--- Running migration:', f, '---');
      const content = await readFile(p, 'utf8');
      try {
        const res = await client.query(content);
        console.log('OK:', f);
      } catch (err) {
        console.error('Error running', f, ':', err.message || err);
        // continue to next migration (or choose to exit)
        // process.exit(1);
      }
    }
    console.log('\nMigrations finished');
  } catch (err) {
    console.error('Migration runner error', err);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
