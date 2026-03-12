# ShareQuest Monorepo

This repo contains the frontend and a Vercel serverless API under `vercel/`.

Useful scripts (from repo root):

- Start local Vercel dev server:

```bash
npm run vercel:start
```

- Run DB migrations (ensure `DATABASE_URL` env var set):

```bash
npm run vercel:migrate
```

- Create a token for a user (prints raw token):

```bash
npm run vercel:create-token -- --user <USER_ID>
```

- Mark a user as admin:

```bash
npm run vercel:mark-admin -- --user <USER_ID>
```

- Run integration test (requires TEST_API_TOKEN env var):

```bash
npm run vercel:integration-test
```

See `vercel/README.md` for more details.

## CI Integration Test

I added a GitHub Actions workflow at `.github/workflows/integration.yml` that lets you run the integration tests against a staging deployment. It requires the following repository secrets to be configured in GitHub:

- STAGING_BASE_URL — e.g. https://staging.sharequest.co.uk (the base URL of your staging deployment)
- TEST_API_TOKEN — a token (raw) to be used for authenticated API calls in CI
- TOKEN_HMAC_SECRET — optional; if you use HMAC tokens set this so CI token verification works
- REDIS_URL — optional; if your staging environment uses Redis for rate limiting

To run the workflow manually from the GitHub Actions UI, click "Run workflow" on the workflow page.
# sharequestapp
