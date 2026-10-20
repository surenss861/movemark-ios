-- PORTED for Neon by neon/port_migrations.py — do not edit by hand.
-- source: supabase/migrations/20260522000001_exports_file_path_nullable.sql (sha256 7f02d05efe2c47d4)
-- change: none (verbatim)

-- movemark-api queues exports before PDF upload; file_path is set on completion.
ALTER TABLE public.exports
  ALTER COLUMN file_path DROP NOT NULL;
