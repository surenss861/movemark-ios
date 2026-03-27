-- MoveMark production: composite PK for move_out_checklist_state

ALTER TABLE public.move_out_checklist_state
  DROP CONSTRAINT IF EXISTS move_out_checklist_state_pkey;

ALTER TABLE public.move_out_checklist_state
  ADD CONSTRAINT move_out_checklist_state_pkey
  PRIMARY KEY (property_id, user_id);
