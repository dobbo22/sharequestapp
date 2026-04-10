# Football Cards

This folder is the dedicated workspace area for the football trading cards app.

It is intentionally separate from the existing ShareQuest iOS app and stock-trading flows.

## Structure

- `backend/` contains football-specific backend notes and config.
- `database/migrations/` contains Neon/Postgres schema migrations for the football app.
- `ios/FootballCards/` is reserved for the separate SwiftUI app source.

## Database

The football app uses the existing Neon Postgres connection already configured for the repo through `API_DATABASE_URL` or `DATABASE_URL`.

To apply migrations, use the existing Vercel migration runner. It now also loads SQL files from `football-cards/database/migrations/`.

```bash
export CONFIRM_MIGRATE=yes
npm run vercel:migrate
```

## Initial Scope

- England only: Premier League, Championship, League One, League Two
- Shared auth identity with football-specific profile tables
- Starter squad generation of 22 cards
- Collection ownership and direct trade offers