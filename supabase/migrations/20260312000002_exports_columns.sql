-- MoveMark production: exports status and metadata

ALTER TABLE public.exports
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'completed',
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS error_message text NULL;

ALTER TABLE public.exports
  DROP CONSTRAINT IF EXISTS exports_status_check;

ALTER TABLE public.exports
  ADD CONSTRAINT exports_status_check
  CHECK (status IN ('queued', 'completed', 'failed'));
