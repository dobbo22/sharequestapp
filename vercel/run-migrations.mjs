#!/usr/bin/env node
import { readFile, readdir } from 'fs/promises';
import { getPool } from './api/_db.js';
import { getFootballPool } from './api/football/_db.js';
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
  const footballPool = getFootballPool();
  const footballClient = await footballPool.connect();
  try {
    const migrationsDir = path.join(__dirname, 'migrations');
    const footballMigrationsDir = path.join(__dirname, '..', 'football-cards', 'database', 'migrations');
    console.log('migrationsDir=', migrationsDir);

    const coreFiles = [
      '001_create_users.sql',
      '002_create_api_tokens.sql',
      '003_create_items.sql',
      '004_create_sq_schema_and_tables.sql',
      '005_add_hash_algo_to_sq_api_tokens.sql',
      '006_add_apple_provider_id_to_users.sql',
    ];

    for (const fileName of coreFiles) {
      const filePath = path.join(migrationsDir, fileName);
      console.log('reading', filePath);
      const content = await readFile(filePath, 'utf8');
      console.log('Running', fileName);
      await client.query(content);
    }

    try {
      const footballFiles = (await readdir(footballMigrationsDir))
        .filter((fileName) => fileName.endsWith('.sql'))
        .sort();

      for (const fileName of footballFiles) {
        const filePath = path.join(footballMigrationsDir, fileName);
        console.log('reading', filePath);
        const content = await readFile(filePath, 'utf8');
        console.log('Running', fileName);
        await footballClient.query(content);
      }
    } catch (err) {
      if (err.code !== 'ENOENT') {
        throw err;
      }
    }

    console.log('Migrations complete');
    process.exit(0);
  } catch (err) {
    console.error('Migration error', err);
    process.exit(1);
  } finally {
    client.release();
    footballClient.release();
  }
}

run();
