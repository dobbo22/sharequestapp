import { getFootballPool } from '../../../lib/football/db.js';
import { authenticate } from '../../../lib/football/auth.js';

const MAX_DAILY_DISCARDS = 5;

// ---------------------------------------------------------------------------
// POST /api/football/collection/discard  { userCardId }
// Discard an available (non-assigned, non-listed) card. Max 5 per day.
// ---------------------------------------------------------------------------
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST, OPTIONS');
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const auth = await authenticate(req);
  if (!auth?.userId) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const userCardId = typeof req.body?.userCardId === 'string'
    ? req.body.userCardId.trim() : '';

  if (!userCardId) {
    return res.status(400).json({ success: false, error: 'Missing userCardId' });
  }

  const pool = getFootballPool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Check + update discard quota atomically
    const today = new Date().toISOString().slice(0, 10);

    const profileResult = await client.query(
      `SELECT daily_discard_date, COALESCE(daily_discards_used, 0) AS daily_discards_used
       FROM sq.football_profiles WHERE user_id = $1 FOR UPDATE LIMIT 1`,
      [auth.userId]
    );
    const profile = profileResult.rows[0];
    const discardDate = profile?.daily_discard_date
      ? String(profile.daily_discard_date).slice(0, 10) : null;
    const usedToday = discardDate === today ? (profile?.daily_discards_used ?? 0) : 0;

    if (usedToday >= MAX_DAILY_DISCARDS) {
      await client.query('ROLLBACK');
      return res.status(429).json({
        success: false,
        error: `Daily discard limit reached (${MAX_DAILY_DISCARDS} per day)`,
        discardsRemaining: 0,
      });
    }

    // Verify card belongs to user, is owned, and not in a squad slot or active exchange listing
    const cardResult = await client.query(
      `SELECT uc.id::text AS "userCardId"
       FROM sq.football_user_cards uc
       WHERE uc.id::text = $1
         AND uc.user_id = $2
         AND uc.ownership_status = 'owned'
         AND uc.starter_slot_code IS NULL
       LIMIT 1`,
      [userCardId, auth.userId]
    );

    if (cardResult.rowCount !== 1) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        success: false,
        error: 'Card not found, not owned, or currently in a squad slot',
      });
    }

    // Check not actively listed on exchange
    const listedResult = await client.query(
      `SELECT id FROM sq.football_exchange_listings
       WHERE user_card_id = $1 AND status = 'active' LIMIT 1`,
      [userCardId]
    );
    if (listedResult.rowCount > 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        success: false,
        error: 'Card is listed on the exchange — remove it first',
      });
    }

    // Mark card as discarded
    await client.query(
      `UPDATE sq.football_user_cards
       SET ownership_status = 'discarded',
           metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
             'disposition', 'user_discarded',
             'discardedAt', NOW()
           )
       WHERE id::text = $1 AND user_id = $2`,
      [userCardId, auth.userId]
    );

    // Increment daily discard counter
    await client.query(
      `UPDATE sq.football_profiles
       SET daily_discard_date  = $1::DATE,
           daily_discards_used = CASE WHEN daily_discard_date = $1::DATE
                                      THEN daily_discards_used + 1
                                      ELSE 1 END
       WHERE user_id = $2`,
      [today, auth.userId]
    );

    await client.query('COMMIT');

    const discardsRemaining = MAX_DAILY_DISCARDS - (usedToday + 1);
    return res.status(200).json({
      success: true,
      data: { userCardId, discardsRemaining },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('POST /api/football/collection/discard failed', error);
    return res.status(500).json({ success: false, error: 'Failed to discard card', details: error.message });
  } finally {
    client.release();
  }
}
