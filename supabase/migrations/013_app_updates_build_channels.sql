-- Migration 013: Add build channels and beta access key support to app_updates
-- Supports stable, beta, and dev release channels with hashed beta access keys.

-- 1. Add columns to app_updates
ALTER TABLE public.app_updates ADD COLUMN IF NOT EXISTS build_channel TEXT NOT NULL DEFAULT 'stable';
ALTER TABLE public.app_updates ADD COLUMN IF NOT EXISTS beta_access_key TEXT;
ALTER TABLE public.app_updates ADD COLUMN IF NOT EXISTS build_notes TEXT;
ALTER TABLE public.app_updates ADD COLUMN IF NOT EXISTS release_tag TEXT;
ALTER TABLE public.app_updates ADD COLUMN IF NOT EXISTS rollout_status TEXT DEFAULT 'active';

-- 2. Update unique constraint to include build_channel
ALTER TABLE public.app_updates DROP CONSTRAINT IF EXISTS app_updates_platform_environment_key;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'app_updates_platform_env_channel_key'
  ) THEN
    ALTER TABLE public.app_updates ADD CONSTRAINT app_updates_platform_env_channel_key 
      UNIQUE (platform, environment, build_channel);
  END IF;
END $$;

-- 3. Also add build_channel and release_tag to history and telemetry for audit/tracking
ALTER TABLE public.app_update_history ADD COLUMN IF NOT EXISTS build_channel TEXT NOT NULL DEFAULT 'stable';
ALTER TABLE public.app_update_history ADD COLUMN IF NOT EXISTS release_tag TEXT;
ALTER TABLE public.app_version_telemetry ADD COLUMN IF NOT EXISTS build_channel TEXT NOT NULL DEFAULT 'stable';
