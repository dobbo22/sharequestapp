import { createClient } from 'redis';

let redisClient = null;
if (process.env.REDIS_URL) {
  try {
    redisClient = createClient({ url: process.env.REDIS_URL });
    redisClient.connect().catch((e) => console.error('Redis connect error', e));
  } catch (err) {
    console.error('Failed to init Redis client', err);
    redisClient = null;
  }
}

export async function rateLimit(key, limit = 60, windowSec = 60) {
  const windowMs = windowSec * 1000;
  const now = Date.now();

  if (redisClient) {
    const redisKey = `rl:${key}:${Math.floor(now / windowMs)}`;
    try {
      const count = await redisClient.incr(redisKey);
      if (count === 1) {
        await redisClient.pexpire(redisKey, windowMs);
      }
      const remaining = Math.max(0, limit - count);
      const ttl = await redisClient.pttl(redisKey);
      return { ok: count <= limit, remaining, resetIn: ttl, limit };
    } catch (err) {
      console.error('Redis rateLimit error', err);
    }
  }

  if (!global._sq_rate_limiter) {
    global._sq_rate_limiter = new Map();
  }
  const store = global._sq_rate_limiter;
  const entry = store.get(key) || { count: 0, windowStart: now };
  if (now - entry.windowStart > windowMs) {
    entry.count = 0;
    entry.windowStart = now;
  }
  entry.count += 1;
  store.set(key, entry);
  const remaining = Math.max(0, limit - entry.count);
  const resetIn = Math.max(0, windowMs - (now - entry.windowStart));
  const ok = entry.count <= limit;
  return { ok, remaining, resetIn, limit };
}

export function rateLimitMiddleware(req, res, opts = {}) {
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
  const userId = req.auth && req.auth.userId ? `user:${req.auth.userId}` : null;
  const key = userId || `ip:${ip}`;
  const { limit = 60, windowSec = 60 } = opts;
  const rlPromise = rateLimit(key, limit, windowSec);

  if (rlPromise && typeof rlPromise.then === 'function') {
    rlPromise.then((result) => {
      if (!result.ok) {
        res.setHeader('X-RateLimit-Limit', result.limit);
        res.setHeader('X-RateLimit-Remaining', 0);
        res.setHeader('X-RateLimit-Reset', Math.ceil((Date.now() + result.resetIn) / 1000));
        res.status(429).json({ error: 'Too many requests' });
        return false;
      }
      res.setHeader('X-RateLimit-Limit', result.limit);
      res.setHeader('X-RateLimit-Remaining', result.remaining);
      res.setHeader('X-RateLimit-Reset', Math.ceil((Date.now() + result.resetIn) / 1000));
      return true;
    }).catch((err) => {
      console.error('rateLimitMiddleware async error', err);
      return true;
    });
    return true;
  }

  const result = rlPromise;
  if (!result.ok) {
    res.setHeader('X-RateLimit-Limit', result.limit);
    res.setHeader('X-RateLimit-Remaining', 0);
    res.setHeader('X-RateLimit-Reset', Math.ceil((Date.now() + result.resetIn) / 1000));
    res.status(429).json({ error: 'Too many requests' });
    return false;
  }
  res.setHeader('X-RateLimit-Limit', result.limit);
  res.setHeader('X-RateLimit-Remaining', result.remaining);
  res.setHeader('X-RateLimit-Reset', Math.ceil((Date.now() + result.resetIn) / 1000));
  return true;
}