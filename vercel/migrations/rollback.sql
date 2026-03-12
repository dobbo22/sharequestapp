-- Rollback script for vercel migrations
-- This will remove only the objects created by the vercel migrations (if they exist).
-- DO NOT run this unless you have confirmed it's safe for your environment.

BEGIN;

-- Drop items table if it exists
DROP TABLE IF EXISTS items;

-- Drop api_tokens table if it exists
DROP TABLE IF EXISTS api_tokens;

-- NOTE: We did not modify the existing `users` table. Do NOT drop or alter `users` here.

COMMIT;
