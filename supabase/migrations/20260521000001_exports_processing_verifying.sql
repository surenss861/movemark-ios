-- Export / Reports v2: active processing states for honest job tracking

ALTER TABLE public.exports
  DROP CONSTRAINT IF EXISTS exports_status_check;

ALTER TABLE public.exports
  ADD CONSTRAINT exports_status_check
  CHECK (status IN ('queued', 'processing', 'verifying', 'completed', 'failed'));
