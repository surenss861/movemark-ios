-- PORTED for Neon by neon/port_migrations.py — do not edit by hand.
-- source: supabase/migrations/20260328000001_exports_requested_completed_at.sql (sha256 1f303260f3471ba2)
-- change: none (verbatim)

-- Columns expected by movemark-api exports routes (idempotent).
ALTER TABLE public.exports
  ADD COLUMN IF NOT EXISTS requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;
