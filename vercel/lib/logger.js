export function routeLogger(req, res, extra = {}) {
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
  const now = new Date().toISOString();
  const msg = { time: now, method: req.method, path: req.url, ip, ...extra };
  console.log(JSON.stringify(msg));
}