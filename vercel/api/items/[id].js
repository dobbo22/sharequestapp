import { getPool } from '../../lib/db.js';
import { authenticate, isAdmin } from '../../lib/auth.js';
import { rateLimitMiddleware } from '../../lib/rateLimiter.js';
import { routeLogger } from '../../lib/logger.js';

function validateUpdate(body) {
  const errors = [];
  if (!body || typeof body !== 'object') {
    errors.push({ path: [], message: 'body must be an object' });
    return { valid: false, errors };
  }
  const { title, details, isCompleted, priority } = body;
  if (title !== undefined) {
    if (typeof title !== 'string' || title.trim().length === 0 || title.length > 256) {
      errors.push({ path: ['title'], message: 'title must be a non-empty string (1-256 chars)' });
    }
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
  return { valid: errors.length === 0, errors, sanitized: { title: typeof title === 'string' ? title.trim() : undefined, details: details ?? undefined, isCompleted: typeof isCompleted === 'boolean' ? isCompleted : undefined, priority: typeof priority === 'number' ? priority : undefined } };
}

export default async function handler(req, res) {
  const pool = getPool();
  const id = req.query.id;

  if (!id) {
    res.status(400).json({ error: 'id is required' });
    return;
  }

  if (req.method === 'GET') {
    try {
      const client = await pool.connect();
      try {
        const result = await client.query('SELECT id, title, details, is_completed AS "isCompleted", priority, timestamp, owner_id FROM sq.items WHERE id = $1', [id]);
        if (result.rowCount === 0) return res.status(404).json({ error: 'Not found' });
        routeLogger(req, res, { status: 200, itemId: id });
        res.status(200).json(result.rows[0]);
      } finally {
        client.release();
      }
    } catch (err) {
      console.error('DB error GET /items/:id', err);
      res.status(500).json({ error: 'DB error' });
    }
    return;
  }

  if (req.method === 'PUT' || req.method === 'PATCH') {
    // Require auth and allow owner or admin
    const authUser = await authenticate(req);
    if (!authUser) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    req.auth = authUser;
    if (!rateLimitMiddleware(req, res, { limit: 30, windowSec: 60 })) return;

    // Validate input
    const { valid, errors, sanitized } = validateUpdate(req.body);
    if (!valid) {
      res.status(400).json({ error: 'Invalid payload', details: errors });
      return;
    }

    try {
      const { title = null, details = null, isCompleted = null, priority = null } = sanitized;
      const client = await pool.connect();
      try {
        // Only allow update if owner_id matches authenticated user or admin
        const result = await client.query(
          'UPDATE sq.items SET title = COALESCE($1, title), details = COALESCE($2, details), is_completed = COALESCE($3, is_completed), priority = COALESCE($4, priority), timestamp = NOW() WHERE id = $5 AND (owner_id = $6 OR $7::boolean) RETURNING id, title, details, is_completed AS "isCompleted", priority, timestamp',
          [title, details, isCompleted, priority, id, authUser.userId, isAdmin(authUser)]
        );
        if (result.rowCount === 0) return res.status(404).json({ error: 'Not found or not owner' });
        routeLogger(req, res, { status: 200, itemId: id, user: authUser.userId });
        res.status(200).json(result.rows[0]);
      } finally {
        client.release();
      }
    } catch (err) {
      console.error('DB error PUT /items/:id', err);
      res.status(500).json({ error: 'DB error' });
    }
    return;
  }

  if (req.method === 'DELETE') {
    // Require auth and allow owner or admin
    const authUser = await authenticate(req);
    if (!authUser) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    req.auth = authUser;
    if (!rateLimitMiddleware(req, res, { limit: 10, windowSec: 60 })) return;

    try {
      const client = await pool.connect();
      try {
        const result = await client.query('DELETE FROM sq.items WHERE id = $1 AND (owner_id = $2 OR $3::boolean)', [id, authUser.userId, isAdmin(authUser)]);
        if (result.rowCount === 0) return res.status(404).json({ error: 'Not found or not owner' });
        routeLogger(req, res, { status: 204, itemId: id, user: authUser.userId });
        res.status(204).end();
      } finally {
        client.release();
      }
    } catch (err) {
      console.error('DB error DELETE /items/:id', err);
      res.status(500).json({ error: 'DB error' });
    }
    return;
  }

  res.setHeader('Allow', 'GET, PUT, PATCH, DELETE');
  res.status(405).end('Method Not Allowed');
}
