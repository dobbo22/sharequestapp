# Vercel Serverless API (Items)

This folder contains a minimal Vercel serverless API implementation for the `items` endpoints backed by Neon Postgres.

Files:
- `api/_db.js` — database pool helper using `pg` Pool and re-using it across invocations.
- `api/items/index.js` — GET /items (list), POST /items (create).
- `api/items/[id].js` — GET /items/:id, PUT /items/:id, DELETE /items/:id.
- `package.json` — minimal dependencies (`pg`) and `vercel dev` script.

Setup
1. Install dependencies (in `vercel/`):

```bash
cd vercel
npm install
```

2. Set environment variables (locally use `.env` or `vercel env add` in production):

- `DATABASE_URL` — Neon connection string (e.g. `postgresql://...?...sslmode=require`).
- `PG_MAX_CLIENTS` — optional, smaller number for serverless (default 5).
- `NEON_REQUIRE_SSL` — set to `1` if you want to force `ssl` config when `NODE_ENV` is not `production`.

3. Run locally with Vercel CLI:

```bash
npm run start
```

Important notes
- Reuse of the `pg` Pool across function invocations reduces connection churn with Neon.
- For production on Vercel you may want to use Neon’s recommended serverless pooling or their connection helper.
- Do NOT commit secrets. Use Vercel's Environment variables UI for production configuration.

Testing
- With the local dev server running, use `curl` or a REST client to call:
  - `GET http://localhost:3000/api/items`
  - `POST http://localhost:3000/api/items` with JSON body `{ "title": "Test" }`

Authentication (added)
- Mutating endpoints (POST /api/items, PUT/PATCH /api/items/:id, DELETE /api/items/:id) require a Bearer token provided in the `Authorization` header.
- Tokens are validated against the `api_tokens` table in Postgres and must be present and not expired.

Creating a test token (one-time SQL)

Run this in your Neon database (replace `USER_ID` with an existing `users.id` UUID):

```sql
INSERT INTO api_tokens (value, user_id, expires_at)
VALUES ('SOME_RANDOM_TEST_TOKEN', 'USER_ID', NOW() + INTERVAL '30 days');
```

You can generate a cryptographically secure token in a script or use `openssl rand -base64 32` for testing.

Example curl calls (replace `SOME_RANDOM_TEST_TOKEN` with the token you inserted):

Create an item (authenticated):

```bash
curl -X POST "http://localhost:3000/api/items" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer SOME_RANDOM_TEST_TOKEN" \
  -d '{"title":"Hello from curl","details":"Created via test","priority":1}'
```

Update an item (authenticated):

```bash
curl -X PUT "http://localhost:3000/api/items/<ITEM_ID>" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer SOME_RANDOM_TEST_TOKEN" \
  -d '{"title":"Updated title"}'
```

Delete an item (authenticated):

```bash
curl -X DELETE "http://localhost:3000/api/items/<ITEM_ID>" \
  -H "Authorization: Bearer SOME_RANDOM_TEST_TOKEN"
```

Notes on permissions
- The implementation enforces that only the owner of an item (owner_id) can update or delete it.
- You can extend the `api_tokens` or `users` tables to include roles/permissions and perform admin checks in `_auth.js` or route handlers.

If you'd like, I can:
- Add a small helper script to create a test token for a given user id.
- Wire JWT tokens instead of DB tokens.
- Add role checks so admins can delete any item.

---

Token creation helper

I added a small Node script at `vercel/scripts/create-token.mjs` which can:
- Insert a DB-backed API token into `api_tokens` for a given user id, or
- Generate a signed JWT if you prefer JWTs (requires `JWT_SECRET` env var).

Usage examples (run from the project root):

Create a DB token for user (expires in 30 days by default):
```bash
node vercel/scripts/create-token.mjs --user <USER_ID>
```

Create a JWT (expires 7 days by default):
```bash
export JWT_SECRET=your_jwt_secret_here
node vercel/scripts/create-token.mjs --user <USER_ID> --jwt
```

Admin notes
- The `authenticate` helper now returns the user's `role` (from `users.role`) and the handlers allow an `admin` to update/delete any item. To make a user an admin, set `role = 'admin'` in the `users` table.

Migrations

You can run the SQL migrations against your Neon database using the `run-migrations.mjs` script. Ensure `DATABASE_URL` is set in your environment.

```bash
# from repo root
npm run vercel:migrate
# or directly
cd vercel
node run-migrations.mjs
```

This will execute the SQL files in `vercel/migrations/` in order (users, api_tokens, items).

IMPORTANT SAFETY NOTES

- I have added SQL migration files under `vercel/migrations/` and a migration runner `run-migrations.mjs` for convenience. However, by default `run-migrations.mjs` will NOT run unless you set the environment variable `CONFIRM_MIGRATE=yes` to guard against accidental execution.

- The migrations create `items` and `api_tokens` tables (they DO NOT modify your existing `users` table). Nevertheless, because your production site (`sharequest.co.uk`) uses the same database, please DO NOT run migrations on the production DB unless you are certain.

Rollback

- I added a rollback script at `vercel/migrations/rollback.sql` that will DROP the `items` and `api_tokens` tables if you decide to remove them. It will not touch the `users` table.

To rollback (manual, from repo root):

```bash
export DATABASE_URL="<your DATABASE_URL>"
cd vercel
# run rollback (this will DROP vercel-created tables)
node -e "import('./api/_db.js').then(m=>m.getPool()).then(async pool=>{const c=await pool.connect(); try{const sql=await (await import('fs/promises')).readFile('./migrations/rollback.sql','utf8'); await c.query(sql); console.log('Rollback executed'); }catch(e){console.error(e);} finally{c.release(); process.exit(0)}})"
```

Verify what exists

- To verify the presence of the created tables, you can query information_schema or use psql. For example:

```sql
SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('items','api_tokens');
```

Next steps I recommend

1. Do NOT run migrations on production until you have a database backup and maintenance window.
2. If you want, I can:
   - Run the rollback for you now (I will only do so if you explicitly confirm and accept the risk).
   - Modify the migration scripts to be purely non-destructive (create only if not exists) — already done.
   - Add a DB prefix (e.g., `sq_`) to the created tables to clearly namespace them and avoid collision.
