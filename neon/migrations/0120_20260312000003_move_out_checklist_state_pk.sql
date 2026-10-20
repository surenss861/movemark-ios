-- PORTED for Neon by neon/port_migrations.py — do not edit by hand.
-- source: supabase/migrations/20260312000003_move_out_checklist_state_pk.sql (sha256 a5be94ab3f155114)
-- change: none (verbatim)

-- MoveMark production: composite PK for move_out_checklist_state

ALTER TABLE public.move_out_checklist_state
  DROP CONSTRAINT IF EXISTS move_out_checklist_state_pkey;

ALTER TABLE public.move_out_checklist_state
  ADD CONSTRAINT move_out_checklist_state_pkey
  PRIMARY KEY (property_id, user_id);
