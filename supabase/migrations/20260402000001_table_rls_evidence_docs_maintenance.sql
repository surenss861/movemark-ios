-- MoveMark: RLS for inspection_items, evidence_files, property_documents, maintenance_issues.
-- Fixes "new row violates row-level security policy" on room evidence / maintenance photos / vault docs
-- when storage buckets exist but table INSERT checks are too strict or policies are missing on remote.

-- Idempotent: enable RLS (no-op if already on).
ALTER TABLE public.inspection_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_issues ENABLE ROW LEVEL SECURITY;

-- Drop policies from 20260312000007 (direct) and 20260312000008 (indirect); also drop this file's names if re-run.
DROP POLICY IF EXISTS "inspection_items_select_via_inspection" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_insert_via_inspection" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_update_via_inspection" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_delete_via_inspection" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_select_own" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_insert_own" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_update_own" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_delete_own" ON public.inspection_items;

DROP POLICY IF EXISTS "evidence_files_select_own" ON public.evidence_files;
DROP POLICY IF EXISTS "evidence_files_insert_own" ON public.evidence_files;
DROP POLICY IF EXISTS "evidence_files_update_own" ON public.evidence_files;
DROP POLICY IF EXISTS "evidence_files_delete_own" ON public.evidence_files;

DROP POLICY IF EXISTS "property_documents_select_own" ON public.property_documents;
DROP POLICY IF EXISTS "property_documents_insert_own" ON public.property_documents;
DROP POLICY IF EXISTS "property_documents_update_own" ON public.property_documents;
DROP POLICY IF EXISTS "property_documents_delete_own" ON public.property_documents;

DROP POLICY IF EXISTS "maintenance_select_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_insert_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_update_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_delete_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_issues_select_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_issues_insert_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_issues_update_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_issues_delete_own" ON public.maintenance_issues;

-- inspection_items: user owns the parent inspection
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

-- evidence_files: own the property (simpler than nested inspection_item requirement; DB still enforces parent FKs)
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

-- property_documents: row user_id + property owned by same user on insert
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

-- maintenance_issues
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
