import { getPool } from './_db.js';
import crypto from 'crypto';

// Authenticate request using Bearer token stored as SHA256/HMAC in `sq.api_tokens.value`.
// Returns an object { userId, role, isAdmin } when authenticated, otherwise null.
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
    // Helper to fetch user info (safe: selects entire user row and inspects available fields)
    async function fetchUserInfo(userId) {
      if (!userId) return { role: 'user', isAdmin: false };
      const ur = await client.query('SELECT * FROM users WHERE user_id = $1 LIMIT 1', [userId]);
      if (ur.rowCount !== 1) return { role: 'user', isAdmin: false };
      const userRow = ur.rows[0];
      const role = (userRow.role && typeof userRow.role === 'string') ? userRow.role : (userRow.is_admin ? 'admin' : 'user');
      const isAdmin = !!userRow.is_admin || role === 'admin';
      return { role, isAdmin };
    }

    // First: try sha256 lookup against sq.api_tokens (no JOIN to avoid missing columns)
    const tokenSha = crypto.createHash('sha256').update(token).digest('hex');
    let r = await client.query(
      `SELECT t.value, t.hash_algo, t.user_id FROM sq.api_tokens t WHERE t.value = $1 LIMIT 1`,
      [tokenSha]
    );
    if (r.rowCount === 1) {
      const row = r.rows[0];
      // If hash_algo missing or indicates sha256, treat as match
      if (!row.hash_algo || row.hash_algo === 'sha256') {
        const ui = await fetchUserInfo(row.user_id);
        return { userId: row.user_id, role: ui.role, isAdmin: ui.isAdmin };
      }
    }

    // Try HMAC if configured
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

    // Fallback: scan candidates and compare in JS (slower, rare)
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

    return null;
  } catch (err) {
    console.error('Auth DB error', err);
    return null;
  } finally {
    client.release();
  }
}

// Helper to check admin role quickly
export function isAdmin(authObj) {
  return authObj && (authObj.isAdmin === true || authObj.role === 'admin');
}
