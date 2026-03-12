#!/usr/bin/env node
import { getPool } from '../api/_db.js';
import { argv } from 'process';

function usage() {
  console.log(`Usage: node mark-admin.mjs --user USER_ID [--role ROLE]

Options:
  --user USER_ID   Required. UUID of existing user in users table.
  --role ROLE      Optional. Role to assign (default: admin).
`);
}

async function main() {
  const args = argv.slice(2);
  const userIndex = args.indexOf('--user');
  if (userIndex === -1 || !args[userIndex + 1]) {
    usage();
    process.exit(1);
  }
  const userId = args[userIndex + 1];
  const roleIndex = args.indexOf('--role');
  const role = roleIndex !== -1 && args[roleIndex + 1] ? args[roleIndex + 1] : 'admin';

  const pool = getPool();
  const client = await pool.connect();
  try {
    const q = 'UPDATE users SET is_admin = $1 WHERE user_id = $2 RETURNING user_id, username, is_admin';
    const r = await client.query(q, [role === 'admin', userId]);
    if (r.rowCount === 0) {
      console.error('No user updated. Ensure user id exists.');
      process.exit(1);
    }
    console.log('User updated:');
    console.log(r.rows[0]);
    process.exit(0);
  } catch (err) {
    console.error('DB error marking admin', err);
    process.exit(1);
  } finally {
    client.release();
  }
}

main();
