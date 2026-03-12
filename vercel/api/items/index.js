import { getPool } from '../_db.js';
import { authenticate } from '../_auth.js';
import { rateLimitMiddleware } from '../_rateLimiter.js';

function validateCreate(body) {
  const errors = [];
  if (!body || typeof body !== 'object') {
    errors.push({ path: [], message: 'body must be an object' });
    return { valid: false, errors };
  }
  const { title, details, isCompleted, priority } = body;
  if (typeof title !== 'string' || title.trim().length === 0 || title.length > 256) {
    errors.push({ path: ['title'], message: 'title must be a non-empty string (1-256 chars)' });
  }
  if (details !== undefined && details !== null && typeof details !== 'string') {
    errors.push({ path: ['details'], message: 'details must be a string' });
  }
  if (details && details.length > 2000) {
    errors.push({ path: ['details'], message: 'details max length 2000' });
  }
  if (isCompleted !== undefined && typeof isCompleted !== 'boolean') {
    errors.push({ path: ['isCompleted'], message: 'isCompleted must be boolean' });
  }
  if (priority !== undefined) {
    if (typeof priority !== 'number' || !Number.isInteger(priority) || priority < 0 || priority > 10) {
      errors.push({ path: ['priority'], message: 'priority must be integer 0-10' });
    }
  }
  return { valid: errors.length === 0, errors, sanitized: { title: typeof title === 'string' ? title.trim() : title, details: details ?? null, isCompleted: !!isCompleted, priority: typeof priority === 'number' ? priority : 0 } };
}

export default async function handler(req, res) {
  const pool = getPool();

  if (req.method === 'GET') {
    try {
      const client = await pool.connect();
      try {
        const result = await client.query('SELECT id, title, details, is_completed AS "isCompleted", priority, timestamp FROM sq.items ORDER BY timestamp DESC LIMIT 100');
        res.status(200).json(result.rows);
      } finally {
        client.release();
      }
    } catch (err) {
      console.error('DB error GET /items', err);
      res.status(500).json({ error: 'DB error' });
    }
    return;
  }

  if (req.method === 'POST') {
    // Require authentication
    const authUser = await authenticate(req);
    if (!authUser) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    // rate limit per user
    req.auth = authUser;
    if (!rateLimitMiddleware(req, res, { limit: 30, windowSec: 60 })) return;

    // Validate input
    const { valid, errors, sanitized } = validateCreate(req.body);
    if (!valid) {
      res.status(400).json({ error: 'Invalid payload', details: errors });
      return;
    }

    try {
      const { title, details, isCompleted, priority } = sanitized;
      const client = await pool.connect();
      try {
        const result = await client.query(
          'INSERT INTO sq.items (title, details, is_completed, priority, timestamp, owner_id) VALUES ($1,$2,$3,$4,NOW(), $5) RETURNING id, title, details, is_completed AS "isCompleted", priority, timestamp',
          [title, details || null, isCompleted, priority, authUser.userId]
        );
        res.status(200).json(result.rows[0]);
      } finally {
        client.release();
      }
    } catch (err) {
      console.error('DB error POST /items', err);
      res.status(500).json({ error: 'DB error' });
    }
    return;
  }

  res.setHeader('Allow', 'GET, POST');
  res.status(405).end('Method Not Allowed');
}
