-- Create items table
CREATE TABLE IF NOT EXISTS items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  details text,
  is_completed boolean NOT NULL DEFAULT false,
  priority integer NOT NULL DEFAULT 0,
  timestamp timestamptz NOT NULL DEFAULT NOW(),
  owner_id uuid
);
-- optional: index on owner_id
CREATE INDEX IF NOT EXISTS idx_items_owner_id ON items(owner_id);
