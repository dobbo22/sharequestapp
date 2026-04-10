#!/usr/bin/env node
import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { Pool } from 'pg';

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const value = argv[index + 1] && !argv[index + 1].startsWith('--') ? argv[index + 1] : 'true';
    args[key] = value;
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));
const connectionString = process.env.FOOTBALL_DATABASE_URL;
if (!connectionString) {
  console.error('Missing FOOTBALL_DATABASE_URL');
  process.exit(1);
}

const email = String(args.email || 'admin@footballcards.local').trim().toLowerCase();
const username = String(args.username || 'footballadmin').trim().toLowerCase();
const firstName = String(args['first-name'] || 'Football').trim();
const lastName = String(args['last-name'] || 'Admin').trim();
const password = args.password && args.password !== 'true'
  ? String(args.password)
  : crypto.randomBytes(12).toString('base64url');

const pool = new Pool({
  connectionString,
  ssl: { rejectUnauthorized: false },
  max: parseInt(process.env.FOOTBALL_PG_MAX_CLIENTS || '3', 10),
});

const client = await pool.connect();
try {
  await client.query("SET search_path TO sq, public");

  const existing = await client.query(
    `
      SELECT id::text AS id, username, email
      FROM sq.football_users
      WHERE LOWER(email) = LOWER($1) OR LOWER(username) = LOWER($2)
      LIMIT 1
    `,
    [email, username]
  );

  if (existing.rowCount > 0) {
    const updated = await client.query(
      `
        UPDATE sq.football_users
        SET is_admin = TRUE,
            updated_at = NOW()
        WHERE id::text = $1
        RETURNING id::text AS id, username, email, is_admin
      `,
      [existing.rows[0].id]
    );

    console.log(JSON.stringify({
      action: 'promoted-existing-user',
      user: updated.rows[0],
      password: null,
    }, null, 2));
    process.exit(0);
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const inserted = await client.query(
    `
      INSERT INTO sq.football_users (
        id,
        username,
        email,
        password_hash,
        first_name,
        last_name,
        is_admin,
        email_verified,
        created_at,
        updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, TRUE, TRUE, NOW(), NOW())
      RETURNING id::text AS id, username, email, is_admin
    `,
    [crypto.randomUUID(), username, email, passwordHash, firstName || null, lastName || null]
  );

  console.log(JSON.stringify({
    action: 'created-admin-user',
    user: inserted.rows[0],
    password,
  }, null, 2));
} finally {
  client.release();
  await pool.end();
}
