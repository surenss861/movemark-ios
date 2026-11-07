-- PORTED for Neon by neon/port_migrations.py — do not edit by hand.
-- source: supabase/migrations/20260313000003_properties_lease_rent.sql (sha256 98149254ee6f93b2)
-- change: none (verbatim)

-- Add lease start and rent amount to properties for full field parity (optional).
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS lease_start date NULL;

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS rent_amount numeric(12, 2) NULL;
