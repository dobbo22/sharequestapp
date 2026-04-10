-- Migration: daily pack claim tracking + server-side discard tracking
-- 2026-04-10

-- Allow 'discarded' as a valid ownership status
ALTER TABLE sq.football_user_cards
  DROP CONSTRAINT IF EXISTS football_user_cards_ownership_status_check;
ALTER TABLE sq.football_user_cards
  ADD CONSTRAINT football_user_cards_ownership_status_check
  CHECK (ownership_status IN ('owned', 'locked', 'traded', 'discarded'));

-- Daily pack claim timestamp + discard quota tracking
ALTER TABLE sq.football_profiles
  ADD COLUMN IF NOT EXISTS daily_pack_claimed_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS daily_discard_date      DATE,
  ADD COLUMN IF NOT EXISTS daily_discards_used     SMALLINT NOT NULL DEFAULT 0;

-- Index for fast daily pack eligibility check
CREATE INDEX IF NOT EXISTS idx_football_profiles_daily_pack
  ON sq.football_profiles (user_id, daily_pack_claimed_at);
