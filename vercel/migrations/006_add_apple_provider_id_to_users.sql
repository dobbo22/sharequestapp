ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS apple_provider_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_apple_provider_id
ON public.users (apple_provider_id)
WHERE apple_provider_id IS NOT NULL;
