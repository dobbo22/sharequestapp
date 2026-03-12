#!/usr/bin/env node
import { getPool } from '../api/_db.js';
import { argv } from 'process';

// Simple script to create a user and print the id. Usage:
// node create-user.mjs --username alice --email alice@example.com

function parseArgs() {
  const args = argv.slice(2);
  const out = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--username' && args[i+1]) { out.username = args[i+1]; i++; }
    else if (args[i] === '--email' && args[i+1]) { out.email = args[i+1]; i++; }
  }
  return out;
}

async function main() {
  const { username = 'testuser', email = 'test@example.com' } = parseArgs();
  const pool = getPool();
  const client = await pool.connect();
  try {
    const q = 'INSERT INTO users (username, email, is_admin, email_verified) VALUES ($1, $2, $3, $4) RETURNING user_id, username';
    const r = await client.query(q, [username, email, false, true]);
    console.log(r.rows[0].user_id);
    process.exit(0);
  } catch (err) {
    console.error('Error creating user', err);
    process.exit(1);
  } finally {
    client.release();
  }
}

main();
