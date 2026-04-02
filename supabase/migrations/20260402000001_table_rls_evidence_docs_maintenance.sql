-- MoveMark: RLS for inspection_items, evidence_files, property_documents, maintenance_issues.
-- Fixes "new row violates row-level security policy" on room evidence / maintenance photos / vault docs
-- when storage buckets exist but table INSERT checks are too strict or policies are missing on remote.
--
-- Each section runs only if the table exists (remote schemas may omit tables or use a divergent migration history).
-- If public.inspection_items is missing, room/move-out evidence cannot work until that table exists — pull schema
-- from the project that has it, or align migrations; the iOS app expects table name "inspection_items".

-- inspection_items: user owns the parent inspection
DO $inspection_items$
BEGIN
  IF to_regclass('public.inspection_items') IS NULL THEN
    RAISE NOTICE 'movemark rls: skipped public.inspection_items (table does not exist)';
    RETURN;
  END IF;
  ALTER TABLE public.inspection_items ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "inspection_items_select_via_inspection" ON public.inspection_items;
  DROP POLICY IF EXISTS "inspection_items_insert_via_inspection" ON public.inspection_items;
  DROP POLICY IF EXISTS "inspection_items_update_via_inspection" ON public.inspection_items;
  DROP POLICY IF EXISTS "inspection_items_delete_via_inspection" ON public.inspection_items;
  DROP POLICY IF EXISTS "inspection_items_select_own" ON public.inspection_items;
  DROP POLICY IF EXISTS "inspection_items_insert_own" ON public.inspection_items;
  DROP POLICY IF EXISTS "inspection_items_update_own" ON public.inspection_items;
  DROP POLICY IF EXISTS "inspection_items_delete_own" ON public.inspection_items;

  CREATE POLICY "inspection_items_select_own"
  ON public.inspection_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.inspections i
      WHERE i.id = inspection_items.inspection_id
        AND i.user_id = auth.uid()
    )
  );

  CREATE POLICY "inspection_items_insert_own"
  ON public.inspection_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.inspections i
      WHERE i.id = inspection_items.inspection_id
        AND i.user_id = auth.uid()
    )
  );

  CREATE POLICY "inspection_items_update_own"
  ON public.inspection_items
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.inspections i
      WHERE i.id = inspection_items.inspection_id
        AND i.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.inspections i
      WHERE i.id = inspection_items.inspection_id
        AND i.user_id = auth.uid()
    )
  );

  CREATE POLICY "inspection_items_delete_own"
  ON public.inspection_items
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.inspections i
      WHERE i.id = inspection_items.inspection_id
        AND i.user_id = auth.uid()
    )
  );
END
$inspection_items$;

-- evidence_files: own the property (DB still enforces parent FKs)
DO $evidence_files$
BEGIN
  IF to_regclass('public.evidence_files') IS NULL THEN
    RAISE NOTICE 'movemark rls: skipped public.evidence_files (table does not exist)';
    RETURN;
  END IF;
  ALTER TABLE public.evidence_files ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "evidence_files_select_own" ON public.evidence_files;
  DROP POLICY IF EXISTS "evidence_files_insert_own" ON public.evidence_files;
  DROP POLICY IF EXISTS "evidence_files_update_own" ON public.evidence_files;
  DROP POLICY IF EXISTS "evidence_files_delete_own" ON public.evidence_files;

  CREATE POLICY "evidence_files_select_own"
  ON public.evidence_files
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.properties p
      WHERE p.id = evidence_files.property_id
        AND p.user_id = auth.uid()
    )
  );

  CREATE POLICY "evidence_files_insert_own"
  ON public.evidence_files
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.properties p
      WHERE p.id = evidence_files.property_id
        AND p.user_id = auth.uid()
    )
  );

  CREATE POLICY "evidence_files_update_own"
  ON public.evidence_files
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.properties p
      WHERE p.id = evidence_files.property_id
        AND p.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.properties p
      WHERE p.id = evidence_files.property_id
        AND p.user_id = auth.uid()
    )
  );

  CREATE POLICY "evidence_files_delete_own"
  ON public.evidence_files
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.properties p
      WHERE p.id = evidence_files.property_id
        AND p.user_id = auth.uid()
    )
  );
END
$evidence_files$;

-- property_documents
DO $property_documents$
BEGIN
  IF to_regclass('public.property_documents') IS NULL THEN
    RAISE NOTICE 'movemark rls: skipped public.property_documents (table does not exist)';
    RETURN;
  END IF;
  ALTER TABLE public.property_documents ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "property_documents_select_own" ON public.property_documents;
  DROP POLICY IF EXISTS "property_documents_insert_own" ON public.property_documents;
  DROP POLICY IF EXISTS "property_documents_update_own" ON public.property_documents;
  DROP POLICY IF EXISTS "property_documents_delete_own" ON public.property_documents;

  CREATE POLICY "property_documents_select_own"
  ON public.property_documents
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

  CREATE POLICY "property_documents_insert_own"
  ON public.property_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.properties p
      WHERE p.id = property_documents.property_id
        AND p.user_id = auth.uid()
    )
  );

  CREATE POLICY "property_documents_update_own"
  ON public.property_documents
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

  CREATE POLICY "property_documents_delete_own"
  ON public.property_documents
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
END
$property_documents$;

-- maintenance_issues
DO $maintenance_issues$
BEGIN
  IF to_regclass('public.maintenance_issues') IS NULL THEN
    RAISE NOTICE 'movemark rls: skipped public.maintenance_issues (table does not exist)';
    RETURN;
  END IF;
  ALTER TABLE public.maintenance_issues ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS "maintenance_select_own" ON public.maintenance_issues;
  DROP POLICY IF EXISTS "maintenance_insert_own" ON public.maintenance_issues;
  DROP POLICY IF EXISTS "maintenance_update_own" ON public.maintenance_issues;
  DROP POLICY IF EXISTS "maintenance_delete_own" ON public.maintenance_issues;
  DROP POLICY IF EXISTS "maintenance_issues_select_own" ON public.maintenance_issues;
  DROP POLICY IF EXISTS "maintenance_issues_insert_own" ON public.maintenance_issues;
  DROP POLICY IF EXISTS "maintenance_issues_update_own" ON public.maintenance_issues;
  DROP POLICY IF EXISTS "maintenance_issues_delete_own" ON public.maintenance_issues;

  CREATE POLICY "maintenance_issues_select_own"
  ON public.maintenance_issues
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

  CREATE POLICY "maintenance_issues_insert_own"
  ON public.maintenance_issues
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.properties p
      WHERE p.id = maintenance_issues.property_id
        AND p.user_id = auth.uid()
    )
  );

  CREATE POLICY "maintenance_issues_update_own"
  ON public.maintenance_issues
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

  CREATE POLICY "maintenance_issues_delete_own"
  ON public.maintenance_issues
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
END
$maintenance_issues$;
