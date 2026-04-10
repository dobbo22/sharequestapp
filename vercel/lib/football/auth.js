import jwt from 'jsonwebtoken';
import { getFootballPool } from './db.js';

function getFootballJwtSecret() {
  return process.env.FOOTBALL_JWT_SECRET || process.env.JWT_SECRET || 'football-cards-secret';
}

export function signFootballToken(user) {
  return jwt.sign(
    {
      userId: user.id,
      username: user.username,
      email: user.email,
      isAdmin: user.isAdmin === true,
    },
    getFootballJwtSecret(),
    { expiresIn: '30d' }
  );
}

export function mapFootballUser(row) {
  if (!row) return null;

  return {
    id: String(row.id),
    username: row.username,
    email: row.email,
    first_name: row.first_name || null,
    last_name: row.last_name || null,
    isAdmin: row.is_admin === true,
    apple_provider_id: row.apple_provider_id || null,
    created_at: row.created_at || null,
    updated_at: row.updated_at || null,
    last_login: row.last_login || null,
  };
}

export async function loadFootballUserById(client, userId) {
  const result = await client.query(
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
      WHERE id::text = $1
      LIMIT 1
    `,
    [userId]
  );

  return mapFootballUser(result.rows[0] || null);
}

export async function authenticate(req) {
  const authHeader = req.headers?.authorization || req.headers?.Authorization;
  if (!authHeader || typeof authHeader !== 'string' || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.slice(7).trim();
  if (!token) {
    return null;
  }

  const serviceToken = process.env.FOOTBALL_SERVICE_TOKEN || process.env.FOOTBALL_API_TOKEN;
  if (serviceToken && token === serviceToken) {
    return { userId: 'football-service-token', role: 'service', isAdmin: true };
  }

  let decoded;
  try {
    decoded = jwt.verify(token, getFootballJwtSecret());
  } catch {
    return null;
  }

  const userId = decoded?.userId ? String(decoded.userId) : null;
  if (!userId) {
    return null;
  }

  const pool = getFootballPool();
  const client = await pool.connect();
  try {
    const user = await loadFootballUserById(client, userId);
    if (!user) {
      return null;
    }

    return {
      userId: user.id,
      role: user.isAdmin ? 'admin' : 'user',
      isAdmin: user.isAdmin,
      user,
    };
  } catch (error) {
    console.error('Football auth failed', error);
    return null;
  } finally {
    client.release();
  }
}

export function isAdmin(auth) {
  return auth?.isAdmin === true || auth?.role === 'admin';
}