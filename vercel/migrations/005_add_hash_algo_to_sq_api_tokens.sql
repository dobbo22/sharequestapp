-- Add hash_algo column to sq.api_tokens to indicate how token values are stored (sha256 or hmac-sha256)
ALTER TABLE IF EXISTS sq.api_tokens
  ADD COLUMN IF NOT EXISTS hash_algo text;

-- optional: index on hash_algo
CREATE INDEX IF NOT EXISTS sq_idx_api_tokens_hash_algo ON sq.api_tokens(hash_algo);
