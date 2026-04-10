CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS sq;

CREATE TABLE IF NOT EXISTS sq.football_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    apple_provider_id TEXT UNIQUE,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sq.football_position_slots (
    slot_code TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    sort_order SMALLINT NOT NULL,
    starter_quantity SMALLINT NOT NULL DEFAULT 2,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO sq.football_position_slots (slot_code, display_name, sort_order, starter_quantity)
VALUES
    ('GK', 'Goalkeeper', 1, 2),
    ('RB', 'Right Back', 2, 2),
    ('RCB', 'Right Centre Back', 3, 2),
    ('LCB', 'Left Centre Back', 4, 2),
    ('LB', 'Left Back', 5, 2),
    ('RM', 'Right Midfield', 6, 2),
    ('CM', 'Centre Midfield', 7, 2),
    ('LM', 'Left Midfield', 8, 2),
    ('RW', 'Right Wing', 9, 2),
    ('ST', 'Striker', 10, 2),
    ('LW', 'Left Wing', 11, 2)
ON CONFLICT (slot_code) DO UPDATE
SET display_name = EXCLUDED.display_name,
    sort_order = EXCLUDED.sort_order,
    starter_quantity = EXCLUDED.starter_quantity;

CREATE TABLE IF NOT EXISTS sq.football_leagues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_football_league_id INTEGER NOT NULL,
    season_year INTEGER NOT NULL,
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    country TEXT NOT NULL DEFAULT 'England',
    tier SMALLINT NOT NULL,
    logo_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (api_football_league_id, season_year)
);

CREATE TABLE IF NOT EXISTS sq.football_clubs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_football_team_id INTEGER NOT NULL UNIQUE,
    league_id UUID REFERENCES sq.football_leagues(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    short_name TEXT,
    code TEXT,
    country TEXT NOT NULL DEFAULT 'England',
    founded SMALLINT,
    logo_url TEXT,
    venue_name TEXT,
    venue_city TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sq.football_players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_football_player_id BIGINT NOT NULL UNIQUE,
    club_id UUID REFERENCES sq.football_clubs(id) ON DELETE SET NULL,
    league_id UUID REFERENCES sq.football_leagues(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    nationality TEXT,
    age SMALLINT,
    position_label TEXT,
    starter_slot_code TEXT REFERENCES sq.football_position_slots(slot_code) ON DELETE SET NULL,
    photo_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sq.football_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL UNIQUE,
    supported_club_id UUID REFERENCES sq.football_clubs(id) ON DELETE SET NULL,
    display_name TEXT,
    starter_pack_status TEXT NOT NULL DEFAULT 'pending' CHECK (starter_pack_status IN ('pending', 'allocated', 'opened')),
    onboarding_completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sq.football_card_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES sq.football_players(id) ON DELETE CASCADE,
    card_type TEXT NOT NULL DEFAULT 'base',
    rarity TEXT NOT NULL DEFAULT 'common',
    season_year INTEGER,
    image_url TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (player_id, card_type, rarity, season_year)
);

CREATE TABLE IF NOT EXISTS sq.football_starter_packs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'allocated' CHECK (status IN ('allocated', 'opened')),
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    opened_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS sq.football_user_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    card_template_id UUID NOT NULL REFERENCES sq.football_card_templates(id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES sq.football_players(id) ON DELETE CASCADE,
    starter_pack_id UUID REFERENCES sq.football_starter_packs(id) ON DELETE SET NULL,
    starter_slot_code TEXT REFERENCES sq.football_position_slots(slot_code) ON DELETE SET NULL,
    starter_slot_copy SMALLINT,
    acquisition_type TEXT NOT NULL DEFAULT 'starter_pack' CHECK (acquisition_type IN ('starter_pack', 'trade', 'admin_grant')),
    ownership_status TEXT NOT NULL DEFAULT 'owned' CHECK (ownership_status IN ('owned', 'locked', 'traded')),
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    traded_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    CHECK (starter_slot_copy IS NULL OR starter_slot_copy IN (1, 2))
);

CREATE TABLE IF NOT EXISTS sq.football_trade_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id TEXT NOT NULL,
    to_user_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    CHECK (from_user_id <> to_user_id)
);

CREATE TABLE IF NOT EXISTS sq.football_trade_offer_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trade_offer_id UUID NOT NULL REFERENCES sq.football_trade_offers(id) ON DELETE CASCADE,
    owner_user_id TEXT NOT NULL,
    user_card_id UUID NOT NULL REFERENCES sq.football_user_cards(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (trade_offer_id, user_card_id)
);

CREATE TABLE IF NOT EXISTS sq.football_sync_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source TEXT NOT NULL DEFAULT 'api-football',
    job_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    requested_by_user_id TEXT,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_football_leagues_tier ON sq.football_leagues (tier, season_year);
CREATE INDEX IF NOT EXISTS idx_football_users_email ON sq.football_users (LOWER(email));
CREATE INDEX IF NOT EXISTS idx_football_users_username ON sq.football_users (LOWER(username));
CREATE INDEX IF NOT EXISTS idx_football_clubs_league_id ON sq.football_clubs (league_id);
CREATE INDEX IF NOT EXISTS idx_football_players_club_id ON sq.football_players (club_id);
CREATE INDEX IF NOT EXISTS idx_football_players_slot ON sq.football_players (starter_slot_code);
CREATE INDEX IF NOT EXISTS idx_football_profiles_supported_club_id ON sq.football_profiles (supported_club_id);
CREATE INDEX IF NOT EXISTS idx_football_user_cards_user_id ON sq.football_user_cards (user_id);
CREATE INDEX IF NOT EXISTS idx_football_user_cards_player_id ON sq.football_user_cards (player_id);
CREATE INDEX IF NOT EXISTS idx_football_user_cards_pack_id ON sq.football_user_cards (starter_pack_id);
CREATE INDEX IF NOT EXISTS idx_football_trade_offers_from_user ON sq.football_trade_offers (from_user_id, status);
CREATE INDEX IF NOT EXISTS idx_football_trade_offers_to_user ON sq.football_trade_offers (to_user_id, status);
CREATE INDEX IF NOT EXISTS idx_football_sync_jobs_status ON sq.football_sync_jobs (status, created_at DESC);