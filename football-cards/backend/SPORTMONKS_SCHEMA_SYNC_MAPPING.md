# Sportmonks Mapping for Current Football Schema

This document maps the current Neon schema to Sportmonks and defines the sync path for starter-card bootstrapping.

## Important Coverage Constraint

With the current Sportmonks free token, the expected England league set is not fully accessible. The configured league IDs for England are still correct for production use, but sync should treat subscription coverage as dynamic.

Configured England league IDs in [football-cards/backend/game-config.json](football-cards/backend/game-config.json):

- Premier League: 8
- Championship: 24
- League One: 72
- League Two: 73

## Keep vs Change Decision

Short-term decision: keep the existing schema physically unchanged and map Sportmonks fields into existing columns.

Reason:

- Avoid a destructive migration while core sync is still being proven.
- Existing app/backend code already expects current table names and relationships.
- Provider neutrality can be improved incrementally via metadata and config.

Recommended medium-term migration (optional): rename provider-specific columns to neutral names once sync is stable.

## Table Mapping

### sq.football_leagues

Current key columns:

- api_football_league_id
- season_year
- name
- tier
- logo_url
- metadata

Sportmonks source:

- League: GET /leagues/{leagueId}?include=seasons
- Fields:
  - league.id -> api_football_league_id (temporary compatibility mapping)
  - season.name (for example 2025/2026) -> season_year (use ending year or configured year rule)
  - league.name -> name
  - config tier -> tier
  - league.image_path -> logo_url
  - league JSON + selected season JSON -> metadata

Upsert key:

- (api_football_league_id, season_year)

### sq.football_clubs

Current key columns:

- api_football_team_id
- league_id
- name
- short_name
- code
- country
- founded
- logo_url
- metadata

Sportmonks source:

- Team membership by season: GET /standings/seasons/{seasonId}?include=participant
- Optional team detail: GET /teams/{teamId}
- Fields:
  - participant.id -> api_football_team_id
  - resolved league row id -> league_id
  - participant.name -> name
  - participant.short_code -> code
  - participant.country_id (resolved to name later if needed) -> metadata.country_id
  - participant.founded -> founded
  - participant.image_path -> logo_url
  - full participant JSON -> metadata

Upsert key:

- api_football_team_id

### sq.football_players

Current key columns:

- api_football_player_id
- club_id
- league_id
- name
- first_name
- last_name
- nationality
- age
- position_label
- starter_slot_code
- photo_url
- metadata

Sportmonks source:

- Squad with nested details:
  - GET /squads/teams/{teamId}?include=player;position;detailedPosition
- Fields:
  - squad.player_id or player.id -> api_football_player_id
  - current club row id -> club_id
  - current league row id -> league_id
  - player.name -> name
  - player.firstname -> first_name
  - player.lastname -> last_name
  - player.nationality_id -> metadata.nationality_id (nationality text may require extra endpoint)
  - player.date_of_birth -> derive age if needed
  - position.name or detailedposition.name -> position_label
  - mapped slot code -> starter_slot_code
  - player.image_path -> photo_url
  - full squad row + player + position objects -> metadata

Upsert key:

- api_football_player_id

## Position Mapping (Sportmonks -> starter slots)

Use detailed position first, then generic position fallback:

- Goalkeeper -> GK
- Right Back / Right Wing Back -> RB
- Centre Back (right bias) -> RCB
- Centre Back (left bias) -> LCB
- Left Back / Left Wing Back -> LB
- Right Midfield / Right Winger -> RM or RW based on detailed label
- Central Midfield / Defensive Midfield / Attacking Midfield -> CM
- Left Midfield / Left Winger -> LM or LW based on detailed label
- Striker / Centre Forward -> ST

If ambiguous, assign CM for midfield and ST for forward, then flag metadata.position_mapping_confidence = low.

## Sync Job Plan

### Job: bootstrap-leagues-clubs-players (source=sportmonks)

1. Load active provider and leagues from [football-cards/backend/game-config.json](football-cards/backend/game-config.json).
2. For each configured league:
   - Request league with seasons include.
   - Select season: current if present, else latest by starting_at.
   - Upsert league row.
3. For selected season:
   - Request standings with participant include.
   - Upsert each participant into clubs.
4. For each club in that league-season:
   - Request squad with player/position includes.
   - Upsert players and slot mapping.
5. Ensure card templates exist for each synced player (base/common default).
6. Write summary counts into sq.football_sync_jobs.details.

### Failure Handling

- If a league is not accessible by subscription, mark as skipped in job details and continue.
- If squad call fails for one club, log and continue; do not fail whole league unless failure rate exceeds threshold.
- Mark job as failed only when no leagues were processed successfully.

## Proposed Follow-up Migration (Optional)

After stable Sportmonks sync, consider this neutralization migration:

- football_leagues.api_football_league_id -> provider_league_id
- football_clubs.api_football_team_id -> provider_team_id
- football_players.api_football_player_id -> provider_player_id
- football_sync_jobs.source default remains dynamic, no hard-coded provider

This is optional for now because compatibility mapping already supports Sportmonks ingestion without breaking existing code.
