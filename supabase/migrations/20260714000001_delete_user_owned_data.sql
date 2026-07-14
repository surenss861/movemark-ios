-- Account deletion support for App Store Guideline 5.1.1(v).
-- Called by movemark-api DELETE /api/account via service_role only.

CREATE OR REPLACE FUNCTION public.delete_user_owned_data(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'target_user_id is required';
  END IF;

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

REVOKE ALL ON FUNCTION public.delete_user_owned_data(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_owned_data(uuid) TO service_role;
