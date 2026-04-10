import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { getPool } from './db.js';

console.log('DEBUG_ENV: SERVICE_API_TOKEN present?', !!process.env.SERVICE_API_TOKEN, 'len=', process.env.SERVICE_API_TOKEN ? process.env.SERVICE_API_TOKEN.length : 0);
console.log('DEBUG_ENV: API_TOKEN present?', !!process.env.API_TOKEN, 'len=', process.env.API_TOKEN ? process.env.API_TOKEN.length : 0);
console.log('DEBUG_ENV: API_DATABASE_URL present?', !!process.env.API_DATABASE_URL || !!process.env.DATABASE_URL);

export async function authenticate(req) {
  const auth = req.headers?.authorization || req.headers?.Authorization;
  if (!auth || typeof auth !== 'string') return null;
  const parts = auth.split(' ');
  if (parts.length !== 2) return null;
  const scheme = parts[0];
  const token = parts[1];
  if (!/^Bearer$/i.test(scheme) || !token) return null;

  const pool = getPool();
  const client = await pool.connect();
  try {
    const serviceToken = process.env.SERVICE_API_TOKEN || process.env.API_TOKEN;
    if (serviceToken && token === serviceToken) {
      return { userId: 'service-token', role: 'service', isAdmin: true };
    }

    async function fetchUserInfo(userId) {
      if (!userId) return { role: 'user', isAdmin: false };
      const ur = await client.query('SELECT * FROM users WHERE user_id = $1 LIMIT 1', [userId]);
      if (ur.rowCount !== 1) return { role: 'user', isAdmin: false };
      const userRow = ur.rows[0];
      const role = (userRow.role && typeof userRow.role === 'string') ? userRow.role : (userRow.is_admin ? 'admin' : 'user');
      const isAdmin = !!userRow.is_admin || role === 'admin';
      return { role, isAdmin };
    }

    const tokenSha = crypto.createHash('sha256').update(token).digest('hex');
    let r = await client.query(
      `SELECT t.value, t.hash_algo, t.user_id FROM sq.api_tokens t WHERE t.value = $1 LIMIT 1`,
      [tokenSha]
    );
    if (r.rowCount === 1) {
      const row = r.rows[0];
      if (!row.hash_algo || row.hash_algo === 'sha256') {
        const ui = await fetchUserInfo(row.user_id);
        return { userId: row.user_id, role: ui.role, isAdmin: ui.isAdmin };
      }
    }

    const secret = process.env.TOKEN_HMAC_SECRET;
    if (secret) {
      const hmac = crypto.createHmac('sha256', secret).update(token).digest('hex');
      r = await client.query(
        `SELECT t.value, t.hash_algo, t.user_id FROM sq.api_tokens t WHERE t.value = $1 LIMIT 1`,
        [hmac]
      );
      if (r.rowCount === 1) {
        const row = r.rows[0];
        const ui = await fetchUserInfo(row.user_id);
        return { userId: row.user_id, role: ui.role, isAdmin: ui.isAdmin };
      }
    }

    const candidates = await client.query("SELECT t.value, t.hash_algo, t.user_id FROM sq.api_tokens t WHERE t.hash_algo IS NOT NULL");
    for (const row of candidates.rows) {
      if (!row.hash_algo || row.hash_algo === 'sha256') {
        const digest = crypto.createHash('sha256').update(token).digest('hex');
        if (digest === row.value) {
          const ui = await fetchUserInfo(row.user_id);
          return { userId: row.user_id, role: ui.role, isAdmin: ui.isAdmin };
        }
      } else if (row.hash_algo === 'hmac-sha256' && secret) {
        const digest = crypto.createHmac('sha256', secret).update(token).digest('hex');
        if (digest === row.value) {
          const ui = await fetchUserInfo(row.user_id);
          return { userId: row.user_id, role: ui.role, isAdmin: ui.isAdmin };
        }
      }
    }

    try {
      const jwtSecret = process.env.JWT_SECRET || 'sharequest-mobile-secret';
      const decoded = jwt.verify(token, jwtSecret);
      const jwtUserId = decoded?.userId ? String(decoded.userId) : null;
      if (jwtUserId) {
        const ui = await fetchUserInfo(jwtUserId);
        return { userId: jwtUserId, role: ui.role, isAdmin: ui.isAdmin };
      }
    } catch {
      // Ignore JWT verification failures.
    }

    return null;
  } catch (err) {
    console.error('Auth DB error', err);
    return null;
  } finally {
    client.release();
  }
}

export function isAdmin(authObj) {
  return authObj && (authObj.isAdmin === true || authObj.role === 'admin');
}