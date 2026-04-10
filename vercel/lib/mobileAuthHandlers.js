import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { getPool } from './db.js';

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

function verifyToken(authHeader) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.substring(7);
  try {
    return jwt.verify(token, process.env.JWT_SECRET || 'sharequest-mobile-secret');
  } catch {
    return null;
  }
}

function hashPassword(password, salt = '') {
  return crypto.createHash('sha256').update(password + salt).digest('hex');
}

async function verifyPassword(password, storedHash, salt = '') {
  if (typeof storedHash === 'string' && storedHash.startsWith('$2')) {
    try {
      return await bcrypt.compare(password, storedHash);
    } catch {
      return false;
    }
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
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const pool = getPool();
    const client = await pool.connect();
    try {
      const { email, password } = req.body || {};

      if (!email || !password) {
        return res.status(400).json({ success: false, error: 'Email and password are required' });
      }

      const userResult = await client.query(
        `SELECT * FROM public.users WHERE LOWER(email) = LOWER($1) OR LOWER(username) = LOWER($1) LIMIT 1`,
        [email]
      );

      if (userResult.rows.length === 0) {
        return res.status(401).json({ success: false, error: 'Invalid email or password' });
      }

      const user = userResult.rows[0];
      const storedHash = user.password_hash || user.password || user.pass || user.passwordHash || null;
      const saltVal = user.salt || user.password_salt || user.passwordSalt || '';

      if (!storedHash) {
        console.error('Login error: user has no stored password hash', { userId: user.user_id || user.id });
        return res.status(500).json({ success: false, error: 'User password not configured' });
      }

      const isValid = await verifyPassword(password, storedHash, saltVal || '');
      if (!isValid) {
        return res.status(401).json({ success: false, error: 'Invalid email or password' });
      }

      const token = jwt.sign(
        {
          userId: user.user_id ? String(user.user_id) : (user.id ? String(user.id) : null),
          username: user.username,
          email: user.email,
          isAdmin: (user.is_admin !== undefined) ? user.is_admin : (user.admin || false),
        },
        process.env.JWT_SECRET || 'sharequest-mobile-secret',
        { expiresIn: '30d' }
      );

      return res.status(200).json({
        success: true,
        token,
        user: {
          id: user.user_id ? String(user.user_id) : (user.id ? String(user.id) : null),
          username: user.username,
          email: user.email,
          first_name: user.first_name || user.firstname || null,
          last_name: user.last_name || user.lastname || null,
          isAdmin: (user.is_admin !== undefined) ? user.is_admin : (user.admin || false),
        },
      });
    } finally {
      client.release();
    }
  } catch (error) {
    if (error && error.statusCode === 400) {
      console.error('Login invalid JSON:', error.message || error);
      return res.status(400).json({ success: false, error: 'Invalid JSON' });
    }
    console.error('Login error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error', details: error.message });
  }
}

async function handleRegister(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { email, username, password, first_name, last_name, date_of_birth } = req.body || {};
    const normalizedEmail = String(email || '').trim().toLowerCase();
    const normalizedUsername = String(username || '').trim().toLowerCase();
    const normalizedPassword = String(password || '').trim();

    if (!normalizedEmail || !normalizedUsername || !normalizedPassword) {
      return res.status(400).json({ success: false, error: 'Email, username, and password are required' });
    }

    if (normalizedPassword.length < 8) {
      return res.status(400).json({ success: false, error: 'Password must be at least 8 characters' });
    }

    const pool = getPool();
    const emailCheck = await pool.query(
      'SELECT user_id FROM public.users WHERE LOWER(email) = LOWER($1)',
      [normalizedEmail]
    );

    if (emailCheck.rows.length > 0) {
      return res.status(409).json({ success: false, error: 'Email already registered' });
    }

    const usernameCheck = await pool.query(
      'SELECT user_id FROM public.users WHERE LOWER(username) = LOWER($1)',
      [normalizedUsername]
    );

    if (usernameCheck.rows.length > 0) {
      return res.status(409).json({ success: false, error: 'Username already taken' });
    }

    const passwordHash = await bcrypt.hash(normalizedPassword, 10);
    const userId = crypto.randomUUID();
    const insertResult = await pool.query(
      `INSERT INTO public.users (user_id, username, email, password_hash, first_name, last_name, date_of_birth, email_verified, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, FALSE, NOW(), NOW())
       RETURNING user_id::text as id, username, email, first_name, last_name`,
      [
        userId,
        normalizedUsername,
        normalizedEmail,
        passwordHash,
        first_name || null,
        last_name || null,
        date_of_birth || null,
      ]
    );

    const user = insertResult.rows[0];
    const token = jwt.sign(
      {
        userId: user.id,
        username: user.username,
        email: user.email,
        isAdmin: false,
      },
      process.env.JWT_SECRET || 'sharequest-mobile-secret',
      { expiresIn: '30d' }
    );

    return res.status(201).json({
      success: true,
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        isAdmin: false,
      },
    });
  } catch (error) {
    console.error('Registration error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error', details: error.message });
  }
}

async function handleMe(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const tokenData = verifyToken(req.headers.authorization);
    if (!tokenData) {
      return res.status(401).json({ success: false, error: 'Unauthorized' });
    }

    const pool = getPool();
    const userResult = await pool.query(
      `SELECT 
         COALESCE(user_id::text, id::text) as id,
         username,
         email,
         COALESCE(first_name, '') as first_name,
         COALESCE(last_name, '') as last_name,
         COALESCE(is_admin, false) as is_admin,
         created_at
       FROM public.users
       WHERE user_id::text = $1 OR id::text = $1`,
      [tokenData.userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    const user = userResult.rows[0];
    return res.status(200).json({
      id: user.id,
      username: user.username,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      isAdmin: user.is_admin || false,
      created_at: user.created_at,
    });
  } catch (error) {
    console.error('Profile error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error', details: error.message });
  }
}

async function handleApple(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const pool = getPool();
  const client = await pool.connect();

  try {
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
    const userEmail = email || claims?.email || null;

    if (!appleId) {
      return res.status(401).json({ success: false, error: 'Could not extract Apple user ID' });
    }

    let userRow = null;

    const byAppleId = await client.query(
      `
        SELECT user_id::text AS id, username, email, first_name, last_name, COALESCE(is_admin, false) AS is_admin
        FROM public.users
        WHERE apple_provider_id = $1
        LIMIT 1
      `,
      [appleId]
    ).catch(() => ({ rows: [] }));

    if (byAppleId.rows.length > 0) {
      userRow = byAppleId.rows[0];
    } else if (userEmail) {
      const byEmail = await client.query(
        `
          SELECT user_id::text AS id, username, email, first_name, last_name, COALESCE(is_admin, false) AS is_admin
          FROM public.users
          WHERE LOWER(email) = LOWER($1)
          LIMIT 1
        `,
        [userEmail]
      );

      if (byEmail.rows.length > 0) {
        userRow = byEmail.rows[0];
        await client.query(
          'UPDATE public.users SET apple_provider_id = $1 WHERE user_id::text = $2',
          [appleId, userRow.id]
        ).catch(() => {});
      }
    }

    if (!userRow) {
      if (!userEmail) {
        return res.status(400).json({ success: false, error: 'Email is required for first-time Apple Sign In' });
      }

      const generatedUserId = crypto.randomUUID();
      const generatedUsername = makeUsername(userEmail);
      const generatedPassword = await bcrypt.hash(crypto.randomUUID(), 10);
      const generatedFirstName = firstName || userEmail.split('@')[0];
      const generatedLastName = lastName || '';

      const inserted = await client.query(
        `
          INSERT INTO public.users (
            user_id,
            username,
            email,
            password_hash,
            first_name,
            last_name,
            email_verified,
            created_at,
            apple_provider_id
          )
          VALUES ($1, $2, $3, $4, $5, $6, TRUE, NOW(), $7)
          RETURNING user_id::text AS id, username, email, first_name, last_name, COALESCE(is_admin, false) AS is_admin
        `,
        [
          generatedUserId,
          generatedUsername,
          userEmail.toLowerCase(),
          generatedPassword,
          generatedFirstName,
          generatedLastName,
          appleId,
        ]
      );

      userRow = inserted.rows[0];
    }

    const token = jwt.sign(
      {
        userId: userRow.id,
        username: userRow.username,
        email: userRow.email,
        isAdmin: userRow.is_admin === true,
      },
      process.env.JWT_SECRET || 'sharequest-mobile-secret',
      { expiresIn: '30d' }
    );

    return res.status(200).json({
      success: true,
      data: {
        token,
        user: {
          id: userRow.id,
          username: userRow.username,
          email: userRow.email,
          first_name: userRow.first_name || null,
          last_name: userRow.last_name || null,
          isAdmin: userRow.is_admin === true,
        },
      },
    });
  } catch (error) {
    console.error('Apple login error:', error);
    return res.status(500).json({ success: false, error: 'Apple sign in failed', details: error.message });
  } finally {
    client.release();
  }
}

export async function handleMobileAuth(req, res, action) {
  setCors(res);

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  switch (action) {
    case 'login':
      return handleLogin(req, res);
    case 'register':
      return handleRegister(req, res);
    case 'me':
      return handleMe(req, res);
    case 'apple':
      return handleApple(req, res);
    default:
      return res.status(404).json({ success: false, error: 'Not found' });
  }
}