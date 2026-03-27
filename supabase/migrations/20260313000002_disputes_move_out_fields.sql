-- Add move-out and charge fields to disputes for full draft round-trip.
-- Safe to run if columns already exist (ALTER TABLE ADD COLUMN IF NOT EXISTS in PG 9.5+).

ALTER TABLE public.disputes
  ADD COLUMN IF NOT EXISTS move_out_date date NULL;

ALTER TABLE public.disputes
  ADD COLUMN IF NOT EXISTS received_itemized boolean NULL DEFAULT false;

ALTER TABLE public.disputes
  ADD COLUMN IF NOT EXISTS charge_date date NULL;
