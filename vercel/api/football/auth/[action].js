import { handleFootballAuth } from '../../../lib/footballAuthHandlers.js';

export default async function handler(req, res) {
  const action = Array.isArray(req.query?.action) ? req.query.action[0] : req.query?.action;
  return handleFootballAuth(req, res, action);
}