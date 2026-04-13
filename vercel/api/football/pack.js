import { getFootballPool } from '../../../lib/football/db.js';
import { authenticate } from '../../../lib/football/auth.js';

const MAX_RESERVE_CARDS = 30;
const MAX_DAILY_DISCARDS = 5;

// Shared card SELECT (matches other endpoints)
function toCardRowSelect(alias = 'uc') {
  return `
    ${alias}.id::text AS "userCardId",
    ${alias}.player_id::text AS "playerId",
    ${alias}.card_template_id::text AS "cardTemplateId",
    p.club_id::text AS "clubId",
    ${alias}.starter_slot_code AS "starterSlotCode",
    ${alias}.starter_slot_copy AS "starterSlotCopy",
    ${alias}.ownership_status AS "ownershipStatus",
    ${alias}.acquired_at AS "acquiredAt",
    p.name AS "playerName",
    p.age AS "age",
    p.position_label AS "positionLabel",
    p.metadata->'detailedPosition'->>'name' AS "detailedPositionLabel",
    NULLIF(p.metadata->'player'->>'height', '')::INT AS "heightCm",
    NULLIF(p.metadata->'player'->>'weight', '')::INT AS "weightKg",
    NULLIF(p.metadata->'performanceStats'->>'appearances', '')::INT AS "appearances",
    NULLIF(p.metadata->'performanceStats'->>'goals', '')::INT AS "goals",
    NULLIF(p.metadata->'performanceStats'->>'assists', '')::INT AS "assists",
    NULLIF(p.metadata->'performanceStats'->>'tackles', '')::INT AS "tackles",
    NULLIF(p.metadata->'performanceStats'->>'shotsOnTarget', '')::INT AS "shotsOnTarget",
    NULLIF(p.metadata->'performanceStats'->>'saves', '')::INT AS "saves",
    NULLIF(p.metadata->'performanceStats'->>'cleanSheets', '')::INT AS "cleanSheets",
    NULLIF(p.metadata->'performanceStats'->>'goalsConceded', '')::INT AS "goalsConceded",
    NULLIF(p.metadata->'performanceStats'->>'passes', '')::INT AS "passes",
    NULLIF(p.metadata->'transferSummary'->>'latestTransferAmount', '')::FLOAT8 AS "latestTransferAmount",
    NULLIF(p.metadata->'ratingSummary'->>'overall', '')::FLOAT8 AS "ratingOutOfTen",
    p.metadata->'ratingSummary'->>'source' AS "ratingSource",
    p.metadata->'ratingSummary'->>'tier' AS "ratingTier",
    NULLIF(CASE WHEN p.photo_url LIKE '%placeholder%' THEN NULL ELSE p.photo_url END, '') AS "photoUrl",
    c.name AS "clubName",
    c.logo_url AS "clubLogoUrl",
    l.name AS "leagueName",
    l.season_year AS "seasonYear"
  `;
}

const playerEligibilityFilter = `COALESCE(NULLIF(p.metadata->'performanceStats'->>'appearances', '')::INT, 0) > 0`;

function isMissingColumnError(error) {
  return error?.code === '42703'; // undefined_column
}

function isSchemaDriftError(error) {
  // undefined_column, undefined_table, undefined_object
  return error?.code === '42703' || error?.code === '42P01' || error?.code === '42704';
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const auth = await authenticate(req);
  if (!auth?.userId) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  if (req.method === 'GET')  return handleGet(req, res, auth);
  if (req.method === 'POST') return handlePost(req, res, auth);

  res.setHeader('Allow', 'GET, POST, OPTIONS');
  return res.status(405).json({ success: false, error: 'Method not allowed' });
}

// ---------------------------------------------------------------------------
// GET /api/football/pack/daily
// Returns eligibility info — no side effects
// ---------------------------------------------------------------------------
async function handleGet(req, res, auth) {
  // ?reserveCount=N from iOS (available + swapQueue + tradeQueue counts)
  const clientReserveCount = req.query?.reserveCount !== undefined
    ? Math.max(0, parseInt(req.query.reserveCount, 10) || 0)
    : null;

  const pool = getFootballPool();
  const client = await pool.connect();
  try {
    const info = await packInfo(client, auth.userId, clientReserveCount);
    return res.status(200).json({ success: true, data: info });
  } catch (error) {
    console.error('GET /api/football/pack/daily failed', error);
    // Keep client UX alive even if this environment has schema drift.
    if (isSchemaDriftError(error)) {
      const reserveCount = clientReserveCount ?? MAX_RESERVE_CARDS;
      const packSize = Math.max(0, MAX_RESERVE_CARDS - reserveCount);
      return res.status(200).json({
        success: true,
        data: {
          available: packSize > 0,
          alreadyClaimed: false,
          packSize,
          reserveCount,
          maxReserve: MAX_RESERVE_CARDS,
          discardsRemaining: MAX_DAILY_DISCARDS,
          maxDailyDiscards: MAX_DAILY_DISCARDS,
          degraded: true,
        },
      });
    }

    return res.status(500).json({ success: false, error: 'Failed to check daily pack', details: error.message });
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// POST /api/football/pack/daily
// Claim today's pack — idempotent within a day
// ---------------------------------------------------------------------------
async function handlePost(req, res, auth) {
  // iOS sends the reserve count it computed locally (available + swap + trade queued)
  // Squad assignments are local-only, so the server trusts the client count
  const clientReserveCount = typeof req.body?.reserveCount === 'number'
    ? Math.max(0, Math.round(req.body.reserveCount))
    : null;

  const pool = getFootballPool();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const info = await packInfo(client, auth.userId, clientReserveCount);

    if (!info.available) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        success: false,
        error: info.alreadyClaimed ? 'Daily pack already claimed today' : 'No cards needed — your reserve is full',
        data: info,
      });
    }

    // Exclude player IDs the user already owns to avoid duplicates
    const ownedResult = await client.query(
      `SELECT DISTINCT player_id::text FROM sq.football_user_cards WHERE user_id = $1 AND ownership_status IN ('owned','locked')`,
      [auth.userId]
    );
    const excludedPlayerIds = ownedResult.rows.map(r => r.player_id);

    // Pick random eligible card templates
    const candidatesResult = await client.query(
      `
        SELECT
          ct.id::text AS "cardTemplateId",
          p.id::text  AS "playerId"
        FROM sq.football_card_templates ct
        INNER JOIN sq.football_players p ON p.id = ct.player_id
        WHERE p.is_active = TRUE
          AND ${playerEligibilityFilter}
          AND ct.card_type = 'base'
          AND ct.rarity = 'common'
          AND NOT (p.id::text = ANY($1::text[]))
        ORDER BY RANDOM()
        LIMIT $2
      `,
      [excludedPlayerIds, info.packSize]
    );

    if (candidatesResult.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ success: false, error: 'No eligible cards available for daily pack' });
    }

    // Insert new cards for the user
    const newCardIds = [];
    for (const candidate of candidatesResult.rows) {
      const insertResult = await client.query(
        `
          INSERT INTO sq.football_user_cards
            (user_id, card_template_id, player_id, acquisition_type, ownership_status, acquired_at, metadata)
          VALUES ($1, $2, $3, 'trade', 'owned', NOW(), $4::jsonb)
          RETURNING id::text AS "userCardId"
        `,
        [
          auth.userId,
          candidate.cardTemplateId,
          candidate.playerId,
          JSON.stringify({ acquisitionSource: 'daily_pack', claimedAt: new Date().toISOString() }),
        ]
      );
      newCardIds.push(insertResult.rows[0].userCardId);
    }

    // Record the claim timestamp if the column exists in this deployment.
    // Some environments can lag migrations; claiming should still succeed.
    try {
      await client.query(
        `UPDATE sq.football_profiles
         SET daily_pack_claimed_at = NOW()
         WHERE user_id = $1`,
        [auth.userId]
      );
    } catch (error) {
      if (!isMissingColumnError(error)) {
        throw error;
      }
    }

    // Fetch full card data for response
    const cardsResult = await client.query(
      `
        SELECT ${toCardRowSelect('uc')}
        FROM sq.football_user_cards uc
        INNER JOIN sq.football_players p ON p.id = uc.player_id
        LEFT JOIN sq.football_clubs c ON c.id = p.club_id
        LEFT JOIN sq.football_leagues l ON l.id = p.league_id
        WHERE uc.id::text = ANY($1::text[])
      `,
      [newCardIds]
    );

    await client.query('COMMIT');

    return res.status(200).json({
      success: true,
      data: {
        cards: cardsResult.rows,
        packSize: cardsResult.rowCount,
        reserveCount: info.reserveCount,
        maxReserve: MAX_RESERVE_CARDS,
      },
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('POST /api/football/pack/daily failed', error);
    return res.status(500).json({ success: false, error: 'Failed to claim daily pack', details: error.message });
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// Shared: compute pack eligibility for a user
// clientReserveCount: iOS-supplied count (available + swap + trade queued).
//   Squad assignments are local-only so server falls back to owned card count.
// ---------------------------------------------------------------------------
async function packInfo(client, userId, clientReserveCount = null) {
  let reserveCount;
  if (clientReserveCount !== null) {
    // Trust the client — it knows local queue state and squad assignments
    // Cap at MAX_RESERVE_CARDS so a malicious value can't generate negative packs
    reserveCount = Math.min(clientReserveCount, MAX_RESERVE_CARDS);
  } else {
    // Fallback: count all owned cards (server doesn't know squad assignments)
    try {
      const countResult = await client.query(
        `SELECT COUNT(*)::INT AS count
         FROM sq.football_user_cards
         WHERE user_id = $1 AND ownership_status = 'owned'`,
        [userId]
      );
      reserveCount = countResult.rows[0].count;
    } catch (error) {
      if (!isSchemaDriftError(error)) {
        throw error;
      }
      reserveCount = MAX_RESERVE_CARDS;
    }
  }

  // Check if already claimed today (UTC day boundary)
  let profile = null;
  try {
    const profileResult = await client.query(
      `SELECT daily_pack_claimed_at,
              daily_discard_date,
              COALESCE(daily_discards_used, 0) AS daily_discards_used
       FROM sq.football_profiles WHERE user_id = $1 LIMIT 1`,
      [userId]
    );
    profile = profileResult.rows[0] ?? null;
  } catch (error) {
    if (!isSchemaDriftError(error)) {
      throw error;
    }
    // Fallback for partially migrated databases: treat as never claimed with full discard quota.
    profile = null;
  }

  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD UTC
  const lastClaimed = profile?.daily_pack_claimed_at
    ? new Date(profile.daily_pack_claimed_at).toISOString().slice(0, 10)
    : null;
  const alreadyClaimed = lastClaimed === today;

  // Discard quota — resets each UTC day
  const discardDate = profile?.daily_discard_date
    ? String(profile.daily_discard_date).slice(0, 10)
    : null;
  const discardsUsedToday = discardDate === today ? (profile?.daily_discards_used ?? 0) : 0;
  const discardsRemaining = Math.max(0, MAX_DAILY_DISCARDS - discardsUsedToday);

  const packSize = Math.max(0, MAX_RESERVE_CARDS - reserveCount);
  const available = !alreadyClaimed && packSize > 0;

  return {
    available,
    alreadyClaimed,
    packSize,
    reserveCount,
    maxReserve: MAX_RESERVE_CARDS,
    discardsRemaining,
    maxDailyDiscards: MAX_DAILY_DISCARDS,
  };
}
