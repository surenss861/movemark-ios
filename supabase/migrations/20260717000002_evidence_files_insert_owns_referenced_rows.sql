-- Tighten evidence_files insert policy: previously only checked that the
-- inserting user owns `property_id`, but never verified that a supplied
-- `inspection_item_id` or `maintenance_issue_id` actually belongs to that
-- same user/property. A user could link their own property's evidence row
-- to another user's inspection_item_id (or maintenance_issue_id) by guessing
-- or enumerating UUIDs. Downstream reads still filter by property_id so this
-- was not an observed read-leak, but it is a real ownership gap on a write path.

DO $evidence_files$
BEGIN
  IF to_regclass('public.evidence_files') IS NULL THEN
    RAISE NOTICE 'movemark rls: skipped public.evidence_files (table does not exist)';
    RETURN;
  END IF;

  DROP POLICY IF EXISTS "evidence_files_insert_own" ON public.evidence_files;

  CREATE POLICY "evidence_files_insert_own" ON public.evidence_files FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.properties p
      WHERE p.id = evidence_files.property_id AND p.user_id = auth.uid()
    )
    AND (
      evidence_files.inspection_item_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.inspection_items ii
        JOIN public.inspections i ON i.id = ii.inspection_id
        WHERE ii.id = evidence_files.inspection_item_id
          AND i.property_id = evidence_files.property_id
          AND i.user_id = auth.uid()
      )
    )
    AND (
      evidence_files.maintenance_issue_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.maintenance_issues mi
        WHERE mi.id = evidence_files.maintenance_issue_id
          AND mi.property_id = evidence_files.property_id
          AND mi.user_id = auth.uid()
      )
    )
  );
END
$evidence_files$;
