-- Columns expected by movemark-api exports routes (idempotent).
ALTER TABLE public.exports
  ADD COLUMN IF NOT EXISTS requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;
