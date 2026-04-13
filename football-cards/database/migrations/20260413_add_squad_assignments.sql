-- Squad assignments: persist per-user slot → card mapping server-side
CREATE TABLE IF NOT EXISTS sq.football_squad_assignments (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       TEXT NOT NULL,
    league_name   TEXT NOT NULL,
    slot_code     TEXT NOT NULL,
    user_card_id  UUID NOT NULL,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, league_name, slot_code)
);

CREATE INDEX IF NOT EXISTS idx_football_squad_assignments_user_id
    ON sq.football_squad_assignments (user_id);
