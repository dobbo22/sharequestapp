#!/usr/bin/env node
import { readFile } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import pkg from 'pg';
const { Pool } = pkg;

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function run() {
  const conn = process.env.DATABASE_URL;
  if (!conn) {
    console.error('ERROR: DATABASE_URL must be set to the owner connection');
    process.exit(1);
  }
  console.log('Using owner connection (redacted)');
  const pool = new Pool({ connectionString: conn, ssl: { rejectUnauthorized: false } });
  const client = await pool.connect();
  try {
    const migrationsDir = path.join(__dirname, '..', 'migrations');
    const files = ['004_create_sq_schema_and_tables.sql','005_add_hash_algo_to_sq_api_tokens.sql'];
    for (const f of files) {
      const p = path.join(migrationsDir, f);
      console.log('\n--- Running migration:', f, '---');
      const content = await readFile(p, 'utf8');
      try {
        const res = await client.query(content);
        console.log('OK:', f);
      } catch (err) {
        console.error('Error running', f, ':', err.message || err);
        throw err;
      }
    }

    // Grant privileges to sharequest_api
    console.log('\n--- Granting privileges to sharequest_api ---');
    try {
      await client.query("GRANT USAGE ON SCHEMA sq TO sharequest_api");
      await client.query("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sq TO sharequest_api");
      await client.query("ALTER DEFAULT PRIVILEGES IN SCHEMA sq GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sharequest_api");
      console.log('Grants applied');
    } catch (err) {
      console.error('Error applying grants:', err.message || err);
      throw err;
    }

    console.log('\nOwner migrations and grants complete');
  } catch (err) {
    console.error('Migration runner error', err);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
