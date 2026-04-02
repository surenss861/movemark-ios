-- Full app RLS hardening for MoveMark
-- Covers user-owned record paths used by iOS:
-- properties, rooms, inspections, inspection_items, inspection_item_tags,
-- evidence_files, maintenance_issues, property_documents,
-- move_out_checklists, move_out_checklist_state,
-- disputes, dispute_evidence_links, exports.
--
-- Ownership model:
--   properties.user_id = auth.uid()
--   inspections.user_id = auth.uid()
--   maintenance_issues.user_id = auth.uid()
--   property_documents.user_id = auth.uid()
--   disputes.user_id = auth.uid()
--   exports.user_id = auth.uid()
-- Child tables authorize through parent rows.
--
-- Replaces / supersedes overlapping policies from:
--   20260312000007_rls_policies_direct.sql
--   20260312000008_rls_policies_indirect.sql
-- (drops legacy policy names first). No explicit transaction wrapper so `db query` / Dashboard runs cleanly.

-- ------------------------------------------------------------
-- Enable RLS
-- ------------------------------------------------------------
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_item_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.move_out_checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.move_out_checklist_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispute_evidence_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exports ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- Drop legacy policies (20260312 indirect naming)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "rooms_select_via_property" ON public.rooms;
DROP POLICY IF EXISTS "rooms_insert_via_property" ON public.rooms;
DROP POLICY IF EXISTS "rooms_update_via_property" ON public.rooms;
DROP POLICY IF EXISTS "rooms_delete_via_property" ON public.rooms;

DROP POLICY IF EXISTS "inspection_items_select_via_inspection" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_insert_via_inspection" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_update_via_inspection" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_delete_via_inspection" ON public.inspection_items;

DROP POLICY IF EXISTS "inspection_item_tags_select_via_item" ON public.inspection_item_tags;
DROP POLICY IF EXISTS "inspection_item_tags_insert_via_item" ON public.inspection_item_tags;
DROP POLICY IF EXISTS "inspection_item_tags_delete_via_item" ON public.inspection_item_tags;

DROP POLICY IF EXISTS "dispute_evidence_links_select_via_dispute" ON public.dispute_evidence_links;
DROP POLICY IF EXISTS "dispute_evidence_links_insert_via_dispute" ON public.dispute_evidence_links;
DROP POLICY IF EXISTS "dispute_evidence_links_update_via_dispute" ON public.dispute_evidence_links;
DROP POLICY IF EXISTS "dispute_evidence_links_delete_via_dispute" ON public.dispute_evidence_links;

-- Legacy maintenance policy names from 20260312000007
DROP POLICY IF EXISTS "maintenance_select_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_insert_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_update_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_delete_own" ON public.maintenance_issues;

-- ------------------------------------------------------------
-- Drop target policies (idempotent re-run)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "properties_select_own" ON public.properties;
DROP POLICY IF EXISTS "properties_insert_own" ON public.properties;
DROP POLICY IF EXISTS "properties_update_own" ON public.properties;
DROP POLICY IF EXISTS "properties_delete_own" ON public.properties;

DROP POLICY IF EXISTS "rooms_select_own" ON public.rooms;
DROP POLICY IF EXISTS "rooms_insert_own" ON public.rooms;
DROP POLICY IF EXISTS "rooms_update_own" ON public.rooms;
DROP POLICY IF EXISTS "rooms_delete_own" ON public.rooms;

DROP POLICY IF EXISTS "inspections_select_own" ON public.inspections;
DROP POLICY IF EXISTS "inspections_insert_own" ON public.inspections;
DROP POLICY IF EXISTS "inspections_update_own" ON public.inspections;
DROP POLICY IF EXISTS "inspections_delete_own" ON public.inspections;

DROP POLICY IF EXISTS "inspection_items_select_own" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_insert_own" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_update_own" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_delete_own" ON public.inspection_items;

DROP POLICY IF EXISTS "inspection_item_tags_select_own" ON public.inspection_item_tags;
DROP POLICY IF EXISTS "inspection_item_tags_insert_own" ON public.inspection_item_tags;
DROP POLICY IF EXISTS "inspection_item_tags_update_own" ON public.inspection_item_tags;
DROP POLICY IF EXISTS "inspection_item_tags_delete_own" ON public.inspection_item_tags;

DROP POLICY IF EXISTS "evidence_files_select_own" ON public.evidence_files;
DROP POLICY IF EXISTS "evidence_files_insert_own" ON public.evidence_files;
DROP POLICY IF EXISTS "evidence_files_update_own" ON public.evidence_files;
DROP POLICY IF EXISTS "evidence_files_delete_own" ON public.evidence_files;

DROP POLICY IF EXISTS "maintenance_issues_select_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_issues_insert_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_issues_update_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_issues_delete_own" ON public.maintenance_issues;

DROP POLICY IF EXISTS "property_documents_select_own" ON public.property_documents;
DROP POLICY IF EXISTS "property_documents_insert_own" ON public.property_documents;
DROP POLICY IF EXISTS "property_documents_update_own" ON public.property_documents;
DROP POLICY IF EXISTS "property_documents_delete_own" ON public.property_documents;

DROP POLICY IF EXISTS "move_out_checklists_select_own" ON public.move_out_checklists;
DROP POLICY IF EXISTS "move_out_checklists_insert_own" ON public.move_out_checklists;
DROP POLICY IF EXISTS "move_out_checklists_update_own" ON public.move_out_checklists;
DROP POLICY IF EXISTS "move_out_checklists_delete_own" ON public.move_out_checklists;

DROP POLICY IF EXISTS "move_out_checklist_state_select_own" ON public.move_out_checklist_state;
DROP POLICY IF EXISTS "move_out_checklist_state_insert_own" ON public.move_out_checklist_state;
DROP POLICY IF EXISTS "move_out_checklist_state_update_own" ON public.move_out_checklist_state;
DROP POLICY IF EXISTS "move_out_checklist_state_delete_own" ON public.move_out_checklist_state;

DROP POLICY IF EXISTS "disputes_select_own" ON public.disputes;
DROP POLICY IF EXISTS "disputes_insert_own" ON public.disputes;
DROP POLICY IF EXISTS "disputes_update_own" ON public.disputes;
DROP POLICY IF EXISTS "disputes_delete_own" ON public.disputes;

DROP POLICY IF EXISTS "dispute_evidence_links_select_own" ON public.dispute_evidence_links;
DROP POLICY IF EXISTS "dispute_evidence_links_insert_own" ON public.dispute_evidence_links;
DROP POLICY IF EXISTS "dispute_evidence_links_update_own" ON public.dispute_evidence_links;
DROP POLICY IF EXISTS "dispute_evidence_links_delete_own" ON public.dispute_evidence_links;

DROP POLICY IF EXISTS "exports_select_own" ON public.exports;
DROP POLICY IF EXISTS "exports_insert_own" ON public.exports;
DROP POLICY IF EXISTS "exports_update_own" ON public.exports;
DROP POLICY IF EXISTS "exports_delete_own" ON public.exports;

-- ------------------------------------------------------------
-- properties
-- ------------------------------------------------------------
CREATE POLICY "properties_select_own"
ON public.properties
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "properties_insert_own"
ON public.properties
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

CREATE POLICY "properties_update_own"
ON public.properties
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "properties_delete_own"
ON public.properties
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ------------------------------------------------------------
-- rooms (authorize through parent property)
-- ------------------------------------------------------------
CREATE POLICY "rooms_select_own"
ON public.rooms
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = rooms.property_id
      AND p.user_id = auth.uid()
  )
);

CREATE POLICY "rooms_insert_own"
ON public.rooms
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = rooms.property_id
      AND p.user_id = auth.uid()
  )
);

CREATE POLICY "rooms_update_own"
ON public.rooms
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = rooms.property_id
      AND p.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = rooms.property_id
      AND p.user_id = auth.uid()
  )
);

CREATE POLICY "rooms_delete_own"
ON public.rooms
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = rooms.property_id
      AND p.user_id = auth.uid()
  )
);

-- ------------------------------------------------------------
-- inspections
-- ------------------------------------------------------------
CREATE POLICY "inspections_select_own"
ON public.inspections
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "inspections_insert_own"
ON public.inspections
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = inspections.property_id
      AND p.user_id = auth.uid()
  )
);

CREATE POLICY "inspections_update_own"
ON public.inspections
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "inspections_delete_own"
ON public.inspections
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ------------------------------------------------------------
-- inspection_items (authorize through parent inspection)
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- inspection_item_tags (authorize through parent inspection_item -> inspection)
-- ------------------------------------------------------------
CREATE POLICY "inspection_item_tags_select_own"
ON public.inspection_item_tags
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.inspection_items ii
    JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE ii.id = inspection_item_tags.inspection_item_id
      AND i.user_id = auth.uid()
  )
);

CREATE POLICY "inspection_item_tags_insert_own"
ON public.inspection_item_tags
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.inspection_items ii
    JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE ii.id = inspection_item_tags.inspection_item_id
      AND i.user_id = auth.uid()
  )
);

CREATE POLICY "inspection_item_tags_update_own"
ON public.inspection_item_tags
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.inspection_items ii
    JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE ii.id = inspection_item_tags.inspection_item_id
      AND i.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.inspection_items ii
    JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE ii.id = inspection_item_tags.inspection_item_id
      AND i.user_id = auth.uid()
  )
);

CREATE POLICY "inspection_item_tags_delete_own"
ON public.inspection_item_tags
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.inspection_items ii
    JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE ii.id = inspection_item_tags.inspection_item_id
      AND i.user_id = auth.uid()
  )
);

-- ------------------------------------------------------------
-- evidence_files (authorize through owned property)
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- maintenance_issues
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- property_documents
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- move_out_checklists
-- ------------------------------------------------------------
CREATE POLICY "move_out_checklists_select_own"
ON public.move_out_checklists
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "move_out_checklists_insert_own"
ON public.move_out_checklists
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = move_out_checklists.property_id
      AND p.user_id = auth.uid()
  )
);

CREATE POLICY "move_out_checklists_update_own"
ON public.move_out_checklists
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "move_out_checklists_delete_own"
ON public.move_out_checklists
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ------------------------------------------------------------
-- move_out_checklist_state
-- ------------------------------------------------------------
CREATE POLICY "move_out_checklist_state_select_own"
ON public.move_out_checklist_state
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "move_out_checklist_state_insert_own"
ON public.move_out_checklist_state
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = move_out_checklist_state.property_id
      AND p.user_id = auth.uid()
  )
);

CREATE POLICY "move_out_checklist_state_update_own"
ON public.move_out_checklist_state
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "move_out_checklist_state_delete_own"
ON public.move_out_checklist_state
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ------------------------------------------------------------
-- disputes
-- ------------------------------------------------------------
CREATE POLICY "disputes_select_own"
ON public.disputes
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "disputes_insert_own"
ON public.disputes
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.properties p
    WHERE p.id = disputes.property_id
      AND p.user_id = auth.uid()
  )
);

CREATE POLICY "disputes_update_own"
ON public.disputes
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "disputes_delete_own"
ON public.disputes
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- ------------------------------------------------------------
-- dispute_evidence_links (authorize through parent dispute)
-- ------------------------------------------------------------
CREATE POLICY "dispute_evidence_links_select_own"
ON public.dispute_evidence_links
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.disputes d
    WHERE d.id = dispute_evidence_links.dispute_id
      AND d.user_id = auth.uid()
  )
);

CREATE POLICY "dispute_evidence_links_insert_own"
ON public.dispute_evidence_links
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.disputes d
    WHERE d.id = dispute_evidence_links.dispute_id
      AND d.user_id = auth.uid()
  )
);

CREATE POLICY "dispute_evidence_links_update_own"
ON public.dispute_evidence_links
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.disputes d
    WHERE d.id = dispute_evidence_links.dispute_id
      AND d.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.disputes d
    WHERE d.id = dispute_evidence_links.dispute_id
      AND d.user_id = auth.uid()
  )
);

CREATE POLICY "dispute_evidence_links_delete_own"
ON public.dispute_evidence_links
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.disputes d
    WHERE d.id = dispute_evidence_links.dispute_id
      AND d.user_id = auth.uid()
  )
);

-- ------------------------------------------------------------
-- exports
-- ------------------------------------------------------------
CREATE POLICY "exports_select_own"
ON public.exports
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "exports_insert_own"
ON public.exports
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND (
    property_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.properties p
      WHERE p.id = exports.property_id
        AND p.user_id = auth.uid()
    )
  )
  AND (
    dispute_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.disputes d
      WHERE d.id = exports.dispute_id
        AND d.user_id = auth.uid()
    )
  )
);

CREATE POLICY "exports_update_own"
ON public.exports
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "exports_delete_own"
ON public.exports
FOR DELETE
TO authenticated
USING (user_id = auth.uid());
