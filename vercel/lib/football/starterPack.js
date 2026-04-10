import { getFootballProviderPreference } from './providerPreference.js';

function chunkArray(items, size) {
  const chunks = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

async function fetchSlotCandidates(client, slotCode, limit, leagueIds) {
  const result = await client.query(
    `
      WITH league_candidates AS (
        SELECT id
        FROM (
          SELECT
            id,
            name,
            season_year,
            updated_at,
            ROW_NUMBER() OVER (
              PARTITION BY LOWER(name)
              ORDER BY season_year DESC, updated_at DESC, id ASC
            ) AS league_rank
          FROM sq.football_leagues
          WHERE api_football_league_id = ANY($3::INT[])
        ) ranked_leagues
        WHERE league_rank = 1
      )
      SELECT
        ct.id AS card_template_id,
        p.id AS player_id,
        p.name AS player_name,
        p.club_id,
        p.photo_url,
        c.name AS club_name
      FROM sq.football_card_templates ct
      INNER JOIN sq.football_players p ON p.id = ct.player_id
      LEFT JOIN sq.football_clubs c ON c.id = p.club_id
      WHERE p.is_active = TRUE
        AND p.starter_slot_code = $1
        AND COALESCE(NULLIF(p.metadata->'performanceStats'->>'appearances', '')::INT, 0) > 0
        AND ct.card_type = 'base'
        AND ct.rarity = 'common'
        AND p.league_id IN (SELECT id FROM league_candidates)
        AND p.photo_url IS NOT NULL
        AND p.photo_url NOT LIKE '%placeholder%'
      ORDER BY RANDOM()
      LIMIT $2
    `,
    [slotCode, limit, leagueIds]
  );

  return result.rows;
}

async function fetchFallbackCandidates(client, limit, leagueIds) {
  const result = await client.query(
    `
      WITH league_candidates AS (
        SELECT id
        FROM (
          SELECT
            id,
            name,
            season_year,
            updated_at,
            ROW_NUMBER() OVER (
              PARTITION BY LOWER(name)
              ORDER BY season_year DESC, updated_at DESC, id ASC
            ) AS league_rank
          FROM sq.football_leagues
          WHERE api_football_league_id = ANY($2::INT[])
        ) ranked_leagues
        WHERE league_rank = 1
      )
      SELECT
        ct.id AS card_template_id,
        p.id AS player_id,
        p.name AS player_name,
        p.starter_slot_code,
        p.club_id,
        p.photo_url,
        c.name AS club_name
      FROM sq.football_card_templates ct
      INNER JOIN sq.football_players p ON p.id = ct.player_id
      LEFT JOIN sq.football_clubs c ON c.id = p.club_id
      WHERE p.is_active = TRUE
        AND COALESCE(NULLIF(p.metadata->'performanceStats'->>'appearances', '')::INT, 0) > 0
        AND ct.card_type = 'base'
        AND ct.rarity = 'common'
        AND p.league_id IN (SELECT id FROM league_candidates)
        AND p.photo_url IS NOT NULL
        AND p.photo_url NOT LIKE '%placeholder%'
      ORDER BY RANDOM()
      LIMIT $1
    `,
    [limit, leagueIds]
  );

  return result.rows;
}

export async function allocateStarterPack(client, { userId, supportedClubId }) {
  const providerPreference = await getFootballProviderPreference();
  const existingPackResult = await client.query(
    `
      SELECT id, status
      FROM sq.football_starter_packs
      WHERE user_id = $1
      LIMIT 1
    `,
    [userId]
  );

  const existingCardCountResult = await client.query(
    `
      SELECT COUNT(*)::INT AS total
      FROM sq.football_user_cards
      WHERE user_id = $1
    `,
    [userId]
  );

  if (existingPackResult.rowCount === 1 && existingCardCountResult.rows[0].total > 0) {
    return {
      starterPackId: existingPackResult.rows[0].id,
      createdCardCount: existingCardCountResult.rows[0].total,
      alreadyExisted: true,
      warnings: [],
    };
  }

  const slotsResult = await client.query(
    `
      SELECT slot_code, starter_quantity
      FROM sq.football_position_slots
      ORDER BY sort_order ASC
    `
  );

  const starterPackResult = existingPackResult.rowCount === 1
    ? existingPackResult
    : await client.query(
        `
          INSERT INTO sq.football_starter_packs (user_id, status, generated_at, metadata)
          VALUES ($1, 'allocated', NOW(), '{}'::jsonb)
          RETURNING id
        `,
        [userId]
      );

  const starterPackId = starterPackResult.rows[0].id;
  const usedPlayerIds = new Set();
  const createdCards = [];
  const warnings = [];

  for (const slot of slotsResult.rows) {
    const desiredCount = Number(slot.starter_quantity) || 0;
    let candidates = await fetchSlotCandidates(
      client,
      slot.slot_code,
      Math.max(desiredCount * 8, 16),
      providerPreference.preferredLeagueIds
    );

    if (candidates.length < desiredCount && providerPreference.fallbackLeagueIds.length > 0) {
      const fallbackCandidates = await fetchSlotCandidates(
        client,
        slot.slot_code,
        Math.max(desiredCount * 8, 16),
        providerPreference.fallbackLeagueIds
      );
      candidates = candidates.concat(fallbackCandidates);
    }

    const chosen = [];

    for (const candidate of candidates) {
      if (!usedPlayerIds.has(candidate.player_id)) {
        chosen.push(candidate);
        usedPlayerIds.add(candidate.player_id);
      }
      if (chosen.length >= desiredCount) {
        break;
      }
    }

    if (chosen.length < desiredCount) {
      let fallbackCandidates = await fetchFallbackCandidates(client, desiredCount * 10, providerPreference.preferredLeagueIds);
      if (providerPreference.fallbackLeagueIds.length > 0) {
        fallbackCandidates = fallbackCandidates.concat(
          await fetchFallbackCandidates(client, desiredCount * 10, providerPreference.fallbackLeagueIds)
        );
      }
      for (const candidate of fallbackCandidates) {
        if (!usedPlayerIds.has(candidate.player_id)) {
          chosen.push(candidate);
          usedPlayerIds.add(candidate.player_id);
        }
        if (chosen.length >= desiredCount) {
          break;
        }
      }
    }

    if (chosen.length < desiredCount) {
      warnings.push(`Only found ${chosen.length}/${desiredCount} starter cards for slot ${slot.slot_code}`);
    }

    chosen.forEach((candidate, index) => {
      createdCards.push({
        slotCode: slot.slot_code,
        starterSlotCopy: index + 1,
        cardTemplateId: candidate.card_template_id,
        playerId: candidate.player_id,
        playerName: candidate.player_name,
        clubId: candidate.club_id,
        clubName: candidate.club_name,
      });
    });
  }

  for (const group of chunkArray(createdCards, 25)) {
    const values = [];
    const placeholders = [];

    group.forEach((card, index) => {
      const offset = index * 7;
      placeholders.push(`($${offset + 1}, $${offset + 2}, $${offset + 3}, $${offset + 4}, $${offset + 5}, $${offset + 6}, 'starter_pack', 'owned', NOW(), $${offset + 7}::jsonb)`);
      values.push(
        userId,
        card.cardTemplateId,
        card.playerId,
        starterPackId,
        card.slotCode,
        card.starterSlotCopy,
        JSON.stringify({
          supportedClubId,
        })
      );
    });

    await client.query(
      `
        INSERT INTO sq.football_user_cards (
          user_id,
          card_template_id,
          player_id,
          starter_pack_id,
          starter_slot_code,
          starter_slot_copy,
          acquisition_type,
          ownership_status,
          acquired_at,
          metadata
        )
        VALUES ${placeholders.join(', ')}
      `,
      values
    );
  }

  await client.query(
    `
      UPDATE sq.football_starter_packs
      SET status = 'opened',
          opened_at = NOW(),
          metadata = $2::jsonb
      WHERE id = $1
    `,
    [
      starterPackId,
      JSON.stringify({
        supportedClubId,
        warnings,
        cardCount: createdCards.length,
      }),
    ]
  );

  await client.query(
    `
      UPDATE sq.football_profiles
      SET starter_pack_status = 'opened',
          updated_at = NOW()
      WHERE user_id = $1
    `,
    [userId]
  );

  return {
    starterPackId,
    createdCardCount: createdCards.length,
    alreadyExisted: false,
    warnings,
  };
}