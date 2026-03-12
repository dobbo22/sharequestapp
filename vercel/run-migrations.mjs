#!/usr/bin/env node
import { readFile } from 'fs/promises';
import { getPool } from './api/_db.js';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function run() {
  // Safety guard: require explicit env var to run migrations
  if (process.env.CONFIRM_MIGRATE !== 'yes') {
    console.error('Aborting migrations: set CONFIRM_MIGRATE=yes to run migrations.');
    process.exit(1);
  }

  const pool = getPool();
  const client = await pool.connect();
  try {
    const migrationsDir = path.join(__dirname, 'migrations');
    console.log('migrationsDir=', migrationsDir);
    const files = ['001_create_users.sql','002_create_api_tokens.sql','003_create_items.sql','004_create_sq_schema_and_tables.sql','005_add_hash_algo_to_sq_api_tokens.sql'];
    for (const f of files) {
      const p = path.join(migrationsDir, f);
      console.log('reading', p);
      const content = await readFile(p, 'utf8');
      console.log('Running', f);
      await client.query(content);
    }
    console.log('Migrations complete');
    process.exit(0);
  } catch (err) {
    console.error('Migration error', err);
    process.exit(1);
  } finally {
    client.release();
  }
}

run();
