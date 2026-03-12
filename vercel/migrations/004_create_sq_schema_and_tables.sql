-- Create schema 'sq' and namespaced tables for the serverless API
CREATE SCHEMA IF NOT EXISTS sq;

-- api tokens (store SHA256 hex of token in value)
CREATE TABLE IF NOT EXISTS sq.api_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  value text NOT NULL UNIQUE,
  user_id uuid NOT NULL,
  expires_at timestamptz,
  created_at timestamptz DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS sq_idx_api_tokens_user_id ON sq.api_tokens(user_id);

-- items table (namespaced)
CREATE TABLE IF NOT EXISTS sq.items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  details text,
  is_completed boolean NOT NULL DEFAULT false,
  priority integer NOT NULL DEFAULT 0,
  timestamp timestamptz NOT NULL DEFAULT NOW(),
  owner_id uuid
);
CREATE INDEX IF NOT EXISTS sq_idx_items_owner_id ON sq.items(owner_id);

-- Note: We intentionally do NOT create FK constraints to existing production tables to avoid collisions.
