-- Create users table (safe: will not override existing columns if present)
CREATE TABLE IF NOT EXISTS users (
  user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL UNIQUE,
  email text UNIQUE,
  password_hash text,
  is_admin boolean NOT NULL DEFAULT false,
  email_verified boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT NOW()
);
