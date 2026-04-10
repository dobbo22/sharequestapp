import { getFootballPool } from '../../../lib/football/db.js';
import { authenticate } from '../../../lib/football/auth.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ success: false, error: 'Method not allowed' });

  const auth = await authenticate(req);
  if (!auth?.userId) return res.status(401).json({ success: false, error: 'Unauthorized' });

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    await client.query(`DELETE FROM sq.football_user_cards WHERE user_id = $1`, [auth.userId]);
    await client.query(`DELETE FROM sq.football_starter_packs WHERE user_id = $1`, [auth.userId]);
    await client.query(
      `UPDATE sq.football_profiles
       SET supported_club_id = NULL,
           team_name = NULL,
           starter_pack_status = 'pending',
           onboarding_completed_at = NULL,
           updated_at = NOW()
       WHERE user_id = $1`,
      [auth.userId]
    );
    await client.query('COMMIT');
    return res.status(200).json({ success: true });
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    return res.status(500).json({ success: false, error: error.message });
  } finally {
    client.release();
  }
}
