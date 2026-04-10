-- Migration: add card exchange listings table and trade rating balance
-- 2026-04-10

-- Track bonus rating points earned from successful sales
ALTER TABLE sq.football_profiles
  ADD COLUMN IF NOT EXISTS trade_rating_balance NUMERIC(5,2) NOT NULL DEFAULT 0;

-- Active and historical exchange listings
CREATE TABLE IF NOT EXISTS sq.football_exchange_listings (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_user_id  TEXT        NOT NULL,
    user_card_id    UUID        NOT NULL REFERENCES sq.football_user_cards(id) ON DELETE CASCADE,
    player_id       UUID        NOT NULL REFERENCES sq.football_players(id) ON DELETE CASCADE,
    card_rating     NUMERIC(5,2),                -- card's ratingOutOfTen at listing time
    rating_cost     NUMERIC(5,2) NOT NULL,        -- card_rating / 2 (what buyer pays)
    status          TEXT        NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'sold', 'removed', 'expired', 'discarded')),
    listed_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,         -- listed_at + 24h, set at insert
    removable_at    TIMESTAMPTZ NOT NULL,         -- listed_at + 6h, set at insert
    buyer_user_id   TEXT,
    completed_at    TIMESTAMPTZ,
    metadata        JSONB       NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_exchange_listings_seller  ON sq.football_exchange_listings (seller_user_id, status);
CREATE INDEX IF NOT EXISTS idx_exchange_listings_status  ON sq.football_exchange_listings (status, expires_at);
CREATE INDEX IF NOT EXISTS idx_exchange_listings_card    ON sq.football_exchange_listings (user_card_id);
