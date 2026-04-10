# Football Backend Notes

This backend stays behind the existing Vercel API layer, but the football app now has its own auth namespace and its own database connection path.

## Planned API Namespace

- `/api/football/auth/*`
- `/api/football/profile`
- `/api/football/clubs`
- `/api/football/collection`
- `/api/football/trades`
- `/api/football/admin/sync`
- `/api/football/admin/sync-status`

## App Flow

- Sign in with email/password or Apple Sign In via `/api/football/auth/*`
- On first launch after auth, call `/api/football/profile`
- If onboarding is incomplete, choose a supported club and POST `/api/football/profile`
- That profile update allocates and opens the user's starter pack in Neon
- The app then reads starter-pack cards and collection summary from the profile response

## Database Separation

- Football routes now use `FOOTBALL_DATABASE_URL` when it is configured.
- If `FOOTBALL_DATABASE_URL` is not set, the football backend temporarily falls back to `API_DATABASE_URL` or `DATABASE_URL` so local development still works.
- Standalone football auth users live in `sq.football_users`.
- To complete the physical DB split, point `FOOTBALL_DATABASE_URL` at a dedicated football Neon database and rerun the football migrations.

## Upstream Source

API-Football is now the default upstream provider for free-tier leagues, clubs, players, and media URLs.

Provider assumptions should stay isolated to sync jobs and adapters. The game schema should stay provider-neutral wherever practical.

The mobile app should not call upstream data providers directly. All normalization and caching should happen server-side.

## Initial Sync Workflow (API-Football)

1. Resolve target leagues from config (England pyramid: Premier League, Championship, League One, League Two).
2. For each league, request teams by league-season.
3. Upsert the league row and all clubs from the teams response.
4. For each club, request the team squad endpoint.
5. Map provider positions to starter slots and upsert players.
6. Ensure base card templates exist for synced players.
7. Record each sync run in `sq.football_sync_jobs` with source=`api-football` and summary counts in details.