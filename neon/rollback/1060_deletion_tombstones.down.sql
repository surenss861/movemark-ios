-- Undoes 1060. Same rule as the others: ships as the next numbered migration, through the runner.
-- Export the table first (scripts/dr/deletion_log.py export): rows dropped here that are not in the
-- external log can't be replayed after a restore.
DROP TRIGGER IF EXISTS properties_record_deletion ON public.properties;
-- Exactly as 0340 and 0960 left them.
CREATE OR REPLACE FUNCTION public.delete_user_owned_data(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'target_user_id is required';
  END IF;

  DELETE FROM public.report_credit_events
  WHERE user_id = target_user_id;

  DELETE FROM public.user_report_credits
  WHERE user_id = target_user_id;

  DELETE FROM public.user_entitlements
  WHERE user_id = target_user_id;

  DELETE FROM public.dispute_evidence_links
  WHERE dispute_id IN (
    SELECT id FROM public.disputes WHERE user_id = target_user_id
  );

  DELETE FROM public.exports
  WHERE user_id = target_user_id;

  DELETE FROM public.inspection_item_tags
  WHERE inspection_item_id IN (
    SELECT ii.id
    FROM public.inspection_items ii
    INNER JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE i.user_id = target_user_id
  );

  DELETE FROM public.evidence_files
  WHERE property_id IN (
    SELECT id FROM public.properties WHERE user_id = target_user_id
  );

  DELETE FROM public.inspection_items
  WHERE inspection_id IN (
    SELECT id FROM public.inspections WHERE user_id = target_user_id
  );

  DELETE FROM public.inspections
  WHERE user_id = target_user_id;

  DELETE FROM public.maintenance_issues
  WHERE user_id = target_user_id;

  DELETE FROM public.property_documents
  WHERE user_id = target_user_id;

  DELETE FROM public.move_out_checklists
  WHERE user_id = target_user_id;

  DELETE FROM public.move_out_checklist_state
  WHERE user_id = target_user_id;

  DELETE FROM public.disputes
  WHERE user_id = target_user_id;

  DELETE FROM public.rooms
  WHERE property_id IN (
    SELECT id FROM public.properties WHERE user_id = target_user_id
  );

  DELETE FROM public.properties
  WHERE user_id = target_user_id;

  DELETE FROM public.profiles
  WHERE id = target_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_auth_user(target_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$ DELETE FROM neon_auth."user" WHERE id = target_user_id $$;

DROP FUNCTION IF EXISTS public.record_property_deletion();
DROP FUNCTION IF EXISTS public.record_deletion(text, uuid);
DROP TABLE IF EXISTS public.deletion_tombstones;
