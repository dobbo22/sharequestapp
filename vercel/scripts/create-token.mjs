#!/usr/bin/env node
import { getPool } from '../api/_db.js';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { argv } from 'process';

function usage() {
  console.log(`Usage: node create-token.mjs --user USER_ID [--jwt] [--expires DAYS]

Options:
  --user USER_ID   Required. UUID of existing user in users table.
  --jwt            Optional. If present, generate and print a signed JWT instead of inserting a DB token.
  --expires DAYS   Optional. Expiry in days (default 30 for DB token, default 7 for JWT).
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
  const useJwt = args.includes('--jwt');
  const expiresIndex = args.indexOf('--expires');
  const expiresDays = expiresIndex !== -1 && args[expiresIndex + 1] ? parseInt(args[expiresIndex + 1], 10) : (useJwt ? 7 : 30);

  if (useJwt) {
    const secret = process.env.JWT_SECRET;
    if (!secret) {
      console.error('JWT_SECRET env var is required to sign JWT');
      process.exit(1);
    }
    const payload = {
      sub: userId,
      role: 'user'
    };
    const token = jwt.sign(payload, secret, { expiresIn: `${expiresDays}d` });
    console.log('Generated JWT (keep secret):');
    console.log(token);
    process.exit(0);
  }

  // Create DB token and insert to sq.api_tokens as SHA256 hash or HMAC if secret provided
  const pool = getPool();
  const client = await pool.connect();
  try {
    const rawToken = crypto.randomBytes(32).toString('base64url');
    const hmacSecret = process.env.TOKEN_HMAC_SECRET;
    let tokenValue, algo;
    if (hmacSecret) {
      tokenValue = crypto.createHmac('sha256', hmacSecret).update(rawToken).digest('hex');
      algo = 'hmac-sha256';
    } else {
      tokenValue = crypto.createHash('sha256').update(rawToken).digest('hex');
      algo = 'sha256';
    }
    const expiresAt = new Date(Date.now() + expiresDays * 24 * 60 * 60 * 1000);
    const q = 'INSERT INTO sq.api_tokens (value, hash_algo, user_id, expires_at) VALUES ($1, $2, $3, $4) RETURNING value, id, user_id, hash_algo, expires_at';
    const params = [tokenValue, algo, userId, expiresAt.toISOString()];
    console.log('DEBUG: SQL:', q);
    console.log('DEBUG: params:', params);
    const r = await client.query(q, params);
    console.log('Inserted DB token (keep the raw token secret):');
    console.log(rawToken);
    process.exit(0);
  } catch (err) {
    console.error('DB error creating token', err);
    process.exit(1);
  } finally {
    client.release();
  }
}

main();
