-- Add lease start and rent amount to properties for full field parity (optional).
ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS lease_start date NULL;

ALTER TABLE public.properties
  ADD COLUMN IF NOT EXISTS rent_amount numeric(12, 2) NULL;
