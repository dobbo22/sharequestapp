import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { getFootballPool } from './football/db.js';
import { authenticate, mapFootballUser, signFootballToken } from './football/auth.js';

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

function hashPassword(password, salt = '') {
  return crypto.createHash('sha256').update(password + salt).digest('hex');
}

async function verifyPassword(password, storedHash, salt = '') {
  if (typeof storedHash === 'string' && storedHash.startsWith('$2')) {
    return bcrypt.compare(password, storedHash);
  }

  return hashPassword(password, salt) === storedHash;
}

function makeUsername(email) {
  const prefix = String(email || 'footballuser')
    .split('@')[0]
    .replace(/[^a-zA-Z0-9]/g, '')
    .toLowerCase() || 'footballuser';
  const suffix = Math.random().toString(36).slice(2, 6);
  return `${prefix}_${suffix}`;
}

async function handleLogin(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '').trim();

  if (!email || !password) {
    return res.status(400).json({ success: false, error: 'Email and password are required' });
  }

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    const result = await client.query(
      `
        SELECT
          id::text AS id,
          username,
          email,
          password_hash,
          first_name,
          last_name,
          COALESCE(is_admin, FALSE) AS is_admin,
          created_at,
          updated_at,
          last_login
        FROM sq.football_users
        WHERE LOWER(email) = LOWER($1) OR LOWER(username) = LOWER($1)
        LIMIT 1
      `,
      [email]
    );

    const row = result.rows[0];
    if (!row?.password_hash) {
      return res.status(401).json({ success: false, error: 'Invalid email or password' });
    }

    const isValid = await verifyPassword(password, row.password_hash);
    if (!isValid) {
      return res.status(401).json({ success: false, error: 'Invalid email or password' });
    }

    await client.query(
      'UPDATE sq.football_users SET last_login = NOW(), updated_at = NOW() WHERE id::text = $1',
      [row.id]
    );

    const user = mapFootballUser({ ...row, last_login: new Date().toISOString() });
    const token = signFootballToken(user);

    return res.status(200).json({ success: true, data: { token, user } });
  } catch (error) {
    console.error('Football login failed', error);
    return res.status(500).json({ success: false, error: 'Football login failed', details: error.message });
  } finally {
    client.release();
  }
}

async function handleRegister(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const email = String(req.body?.email || '').trim().toLowerCase();
  const username = String(req.body?.username || '').trim().toLowerCase();
  const password = String(req.body?.password || '').trim();
  const firstName = typeof req.body?.first_name === 'string' ? req.body.first_name.trim() : null;
  const lastName = typeof req.body?.last_name === 'string' ? req.body.last_name.trim() : null;

  if (!email || !username || !password) {
    return res.status(400).json({ success: false, error: 'Email, username, and password are required' });
  }

  if (password.length < 8) {
    return res.status(400).json({ success: false, error: 'Password must be at least 8 characters' });
  }

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    const emailCheck = await client.query(
      'SELECT id::text FROM sq.football_users WHERE LOWER(email) = LOWER($1) LIMIT 1',
      [email]
    );
    if (emailCheck.rowCount > 0) {
      return res.status(409).json({ success: false, error: 'Email already registered' });
    }

    const usernameCheck = await client.query(
      'SELECT id::text FROM sq.football_users WHERE LOWER(username) = LOWER($1) LIMIT 1',
      [username]
    );
    if (usernameCheck.rowCount > 0) {
      return res.status(409).json({ success: false, error: 'Username already taken' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const userId = crypto.randomUUID();

    const result = await client.query(
      `
        INSERT INTO sq.football_users (
          id,
          username,
          email,
          password_hash,
          first_name,
          last_name,
          email_verified,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, FALSE, NOW(), NOW())
        RETURNING
          id::text AS id,
          username,
          email,
          first_name,
          last_name,
          COALESCE(is_admin, FALSE) AS is_admin,
          apple_provider_id,
          created_at,
          updated_at,
          last_login
      `,
      [userId, username, email, passwordHash, firstName || null, lastName || null]
    );

    const user = mapFootballUser(result.rows[0]);
    const token = signFootballToken(user);

    return res.status(201).json({ success: true, data: { token, user } });
  } catch (error) {
    console.error('Football registration failed', error);
    return res.status(500).json({ success: false, error: 'Football registration failed', details: error.message });
  } finally {
    client.release();
  }
}

async function handleApple(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const { identityToken, email, firstName, lastName, appleUserId } = req.body || {};
  if (!identityToken) {
    return res.status(400).json({ success: false, error: 'identityToken required' });
  }

  let claims;
  try {
    claims = jwt.decode(identityToken);
  } catch {
    return res.status(401).json({ success: false, error: 'Invalid identity token' });
  }

  const appleId = appleUserId || claims?.sub;
  const userEmail = (email || claims?.email || '').trim().toLowerCase() || null;

  if (!appleId) {
    return res.status(401).json({ success: false, error: 'Could not extract Apple user ID' });
  }

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    let result = await client.query(
      `
        SELECT
          id::text AS id,
          username,
          email,
          first_name,
          last_name,
          COALESCE(is_admin, FALSE) AS is_admin,
          apple_provider_id,
          created_at,
          updated_at,
          last_login
        FROM sq.football_users
        WHERE apple_provider_id = $1
        LIMIT 1
      `,
      [appleId]
    );

    let row = result.rows[0] || null;

    if (!row && userEmail) {
      result = await client.query(
        `
          SELECT
            id::text AS id,
            username,
            email,
            first_name,
            last_name,
            COALESCE(is_admin, FALSE) AS is_admin,
            apple_provider_id,
            created_at,
            updated_at,
            last_login
          FROM sq.football_users
          WHERE LOWER(email) = LOWER($1)
          LIMIT 1
        `,
        [userEmail]
      );

      row = result.rows[0] || null;
      if (row) {
        const updated = await client.query(
          `
            UPDATE sq.football_users
            SET apple_provider_id = $2,
                updated_at = NOW(),
                last_login = NOW()
            WHERE id::text = $1
            RETURNING
              id::text AS id,
              username,
              email,
              first_name,
              last_name,
              COALESCE(is_admin, FALSE) AS is_admin,
              apple_provider_id,
              created_at,
              updated_at,
              last_login
          `,
          [row.id, appleId]
        );
        row = updated.rows[0] || row;
      }
    }

    if (!row) {
      if (!userEmail) {
        return res.status(400).json({ success: false, error: 'Email is required for first-time Apple Sign In' });
      }

      const generatedUserId = crypto.randomUUID();
      const generatedUsername = makeUsername(userEmail);
      const generatedPassword = await bcrypt.hash(crypto.randomUUID(), 10);
      const inserted = await client.query(
        `
          INSERT INTO sq.football_users (
            id,
            username,
            email,
            password_hash,
            first_name,
            last_name,
            email_verified,
            created_at,
            updated_at,
            last_login,
            apple_provider_id
          )
          VALUES ($1, $2, $3, $4, $5, $6, TRUE, NOW(), NOW(), NOW(), $7)
          RETURNING
            id::text AS id,
            username,
            email,
            first_name,
            last_name,
            COALESCE(is_admin, FALSE) AS is_admin,
            apple_provider_id,
            created_at,
            updated_at,
            last_login
        `,
        [
          generatedUserId,
          generatedUsername,
          userEmail,
          generatedPassword,
          firstName || userEmail.split('@')[0],
          lastName || null,
          appleId,
        ]
      );
      row = inserted.rows[0];
    }

    const user = mapFootballUser(row);
    const token = signFootballToken(user);

    return res.status(200).json({ success: true, data: { token, user } });
  } catch (error) {
    console.error('Football Apple sign in failed', error);
    return res.status(500).json({ success: false, error: 'Football Apple sign in failed', details: error.message });
  } finally {
    client.release();
  }
}

async function handleMe(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const auth = await authenticate(req);
  if (!auth?.user) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  return res.status(200).json(auth.user);
}

export async function handleFootballAuth(req, res, action) {
  setCors(res);

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  switch (action) {
    case 'login':
      return handleLogin(req, res);
    case 'register':
      return handleRegister(req, res);
    case 'apple':
      return handleApple(req, res);
    case 'me':
      return handleMe(req, res);
    default:
      return res.status(404).json({ success: false, error: 'Not found' });
  }
}