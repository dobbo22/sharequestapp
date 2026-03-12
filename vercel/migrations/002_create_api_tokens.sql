-- Create api_tokens table (store SHA256 hex of token in value)
CREATE TABLE IF NOT EXISTS api_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  value text NOT NULL UNIQUE,
  user_id uuid NOT NULL,
  expires_at timestamptz,
  created_at timestamptz DEFAULT NOW()
);
-- optional: add index on user_id
CREATE INDEX IF NOT EXISTS idx_api_tokens_user_id ON api_tokens(user_id);
