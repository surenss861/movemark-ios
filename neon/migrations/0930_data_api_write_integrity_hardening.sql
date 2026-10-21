-- =============================================================================
-- 0930 — Data API write-integrity hardening (new, 2026-10-20)
-- =============================================================================
-- Found by the SQL review, inherited from the Supabase policies (not introduced
-- by the Neon port). Two classes of hole, both through the Data API role:
--
-- 1. exports were client-writable. A user could insert a queued export for their
--    own property (e.g. dispute_packet) or re-queue/edit one; the worker builds
--    whatever is queued, bypassing the API's Pro and report-credit checks.
--    Exports are now read-only for clients: the API (movemark_backend / owner)
--    queues them and the worker mutates them.
--
-- 2. Several INSERT/UPDATE policies checked that the caller owns the row, but not
--    that the row's parent (property, room, inspection, dispute target) is the
--    caller's and on the same property. A could point A's rows at B's property or
--    room; with NO ACTION foreign keys that made B's rooms/properties — and B's
--    account — undeletable (delete_user_owned_data(B) failed on the FK).
--
-- Every INSERT and UPDATE below now requires, as one invariant:
--   the row is the caller's  AND  every parent it references is the caller's
--   AND  all of them belong to the same property.
-- UPDATE policies keep "is it mine" in USING and enforce the full invariant in
-- WITH CHECK, so a row can't be moved somewhere it couldn't have been inserted.
-- Permissive policies are replaced (not layered), so the stated rule is the rule.
-- The RESTRICTIVE key-folder policies from 0910 still apply on top.
-- Functions: none added; nothing new is callable over /rpc.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. exports: clients read their own rows; nothing else.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "exports_insert_own" ON public.exports;
DROP POLICY IF EXISTS "exports_update_own" ON public.exports;
DROP POLICY IF EXISTS "exports_delete_own" ON public.exports;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.exports FROM authenticated, anonymous;
-- exports_select_own (user_id = caller) stays.

-- -----------------------------------------------------------------------------
-- 2. Rows hanging directly off a property: caller owns the row and the property.
-- -----------------------------------------------------------------------------
-- inspections
DROP POLICY IF EXISTS "inspections_insert_own" ON public.inspections;
DROP POLICY IF EXISTS "inspections_update_own" ON public.inspections;
CREATE POLICY "inspections_insert_own" ON public.inspections FOR INSERT TO authenticated
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = inspections.property_id AND p.user_id = (auth.user_id())::uuid));
CREATE POLICY "inspections_update_own" ON public.inspections FOR UPDATE TO authenticated
  USING (user_id = (auth.user_id())::uuid)
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = inspections.property_id AND p.user_id = (auth.user_id())::uuid)
              -- moving an inspection must not strand its items (or their evidence) on another property
              AND NOT EXISTS (SELECT 1 FROM public.inspection_items ii JOIN public.rooms r ON r.id = ii.room_id
                              WHERE ii.inspection_id = inspections.id AND r.property_id <> inspections.property_id)
              AND NOT EXISTS (SELECT 1 FROM public.inspection_items ii JOIN public.evidence_files ef ON ef.inspection_item_id = ii.id
                              WHERE ii.inspection_id = inspections.id AND ef.property_id <> inspections.property_id));

-- maintenance_issues
DROP POLICY IF EXISTS "maintenance_issues_insert_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_issues_update_own" ON public.maintenance_issues;
CREATE POLICY "maintenance_issues_insert_own" ON public.maintenance_issues FOR INSERT TO authenticated
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = maintenance_issues.property_id AND p.user_id = (auth.user_id())::uuid));
CREATE POLICY "maintenance_issues_update_own" ON public.maintenance_issues FOR UPDATE TO authenticated
  USING (user_id = (auth.user_id())::uuid)
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = maintenance_issues.property_id AND p.user_id = (auth.user_id())::uuid)
              AND NOT EXISTS (SELECT 1 FROM public.evidence_files ef
                              WHERE ef.maintenance_issue_id = maintenance_issues.id AND ef.property_id <> maintenance_issues.property_id)
              AND NOT EXISTS (SELECT 1 FROM public.dispute_evidence_links l JOIN public.disputes d ON d.id = l.dispute_id
                              WHERE l.maintenance_issue_id = maintenance_issues.id AND d.property_id <> maintenance_issues.property_id));

-- property_documents
DROP POLICY IF EXISTS "property_documents_insert_own" ON public.property_documents;
DROP POLICY IF EXISTS "property_documents_update_own" ON public.property_documents;
CREATE POLICY "property_documents_insert_own" ON public.property_documents FOR INSERT TO authenticated
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = property_documents.property_id AND p.user_id = (auth.user_id())::uuid));
CREATE POLICY "property_documents_update_own" ON public.property_documents FOR UPDATE TO authenticated
  USING (user_id = (auth.user_id())::uuid)
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = property_documents.property_id AND p.user_id = (auth.user_id())::uuid)
              AND NOT EXISTS (SELECT 1 FROM public.dispute_evidence_links l JOIN public.disputes d ON d.id = l.dispute_id
                              WHERE l.property_document_id = property_documents.id AND d.property_id <> property_documents.property_id));

-- move_out_checklists
DROP POLICY IF EXISTS "move_out_checklists_insert_own" ON public.move_out_checklists;
DROP POLICY IF EXISTS "move_out_checklists_update_own" ON public.move_out_checklists;
CREATE POLICY "move_out_checklists_insert_own" ON public.move_out_checklists FOR INSERT TO authenticated
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = move_out_checklists.property_id AND p.user_id = (auth.user_id())::uuid));
CREATE POLICY "move_out_checklists_update_own" ON public.move_out_checklists FOR UPDATE TO authenticated
  USING (user_id = (auth.user_id())::uuid)
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = move_out_checklists.property_id AND p.user_id = (auth.user_id())::uuid));

-- move_out_checklist_state (kept: reconstructed, no known users yet — see A13)
DROP POLICY IF EXISTS "move_out_checklist_state_insert_own" ON public.move_out_checklist_state;
DROP POLICY IF EXISTS "move_out_checklist_state_update_own" ON public.move_out_checklist_state;
CREATE POLICY "move_out_checklist_state_insert_own" ON public.move_out_checklist_state FOR INSERT TO authenticated
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = move_out_checklist_state.property_id AND p.user_id = (auth.user_id())::uuid));
CREATE POLICY "move_out_checklist_state_update_own" ON public.move_out_checklist_state FOR UPDATE TO authenticated
  USING (user_id = (auth.user_id())::uuid)
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = move_out_checklist_state.property_id AND p.user_id = (auth.user_id())::uuid));

-- disputes
DROP POLICY IF EXISTS "disputes_insert_own" ON public.disputes;
DROP POLICY IF EXISTS "disputes_update_own" ON public.disputes;
CREATE POLICY "disputes_insert_own" ON public.disputes FOR INSERT TO authenticated
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = disputes.property_id AND p.user_id = (auth.user_id())::uuid));
CREATE POLICY "disputes_update_own" ON public.disputes FOR UPDATE TO authenticated
  USING (user_id = (auth.user_id())::uuid)
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = disputes.property_id AND p.user_id = (auth.user_id())::uuid)
              -- a dispute can't be moved away from the evidence it links
              AND NOT EXISTS (SELECT 1 FROM public.dispute_evidence_links l
                              LEFT JOIN public.evidence_files ef ON ef.id = l.evidence_file_id
                              LEFT JOIN public.maintenance_issues mi ON mi.id = l.maintenance_issue_id
                              LEFT JOIN public.property_documents pd ON pd.id = l.property_document_id
                              WHERE l.dispute_id = disputes.id
                                AND coalesce(ef.property_id, mi.property_id, pd.property_id) <> disputes.property_id));

-- rooms: moving a room to another of the caller's properties must not leave items
-- of an inspection on the old property pointing at it.
DROP POLICY IF EXISTS "rooms_update_own" ON public.rooms;
CREATE POLICY "rooms_update_own" ON public.rooms FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = rooms.property_id AND p.user_id = (auth.user_id())::uuid))
  WITH CHECK (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = rooms.property_id AND p.user_id = (auth.user_id())::uuid)
              AND NOT EXISTS (SELECT 1 FROM public.inspection_items ii JOIN public.inspections i ON i.id = ii.inspection_id
                              WHERE ii.room_id = rooms.id AND i.property_id <> rooms.property_id));

-- -----------------------------------------------------------------------------
-- 3. inspection_items: inspection is the caller's, room is the caller's, and the
--    room is on the inspection's property (no item joining rental A1 to a room of A2).
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "inspection_items_insert_own" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_update_own" ON public.inspection_items;
CREATE POLICY "inspection_items_insert_own" ON public.inspection_items FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1
    FROM public.inspections i
    JOIN public.properties p ON p.id = i.property_id
    JOIN public.rooms r ON r.id = inspection_items.room_id
    WHERE i.id = inspection_items.inspection_id
      AND i.user_id = (auth.user_id())::uuid
      AND p.user_id = (auth.user_id())::uuid
      AND r.property_id = i.property_id
  ));
CREATE POLICY "inspection_items_update_own" ON public.inspection_items FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.inspections i
                 WHERE i.id = inspection_items.inspection_id AND i.user_id = (auth.user_id())::uuid))
  WITH CHECK (EXISTS (
    SELECT 1
    FROM public.inspections i
    JOIN public.properties p ON p.id = i.property_id
    JOIN public.rooms r ON r.id = inspection_items.room_id
    WHERE i.id = inspection_items.inspection_id
      AND i.user_id = (auth.user_id())::uuid
      AND p.user_id = (auth.user_id())::uuid
      AND r.property_id = i.property_id
  ));

-- -----------------------------------------------------------------------------
-- 4. evidence_files UPDATE mirrors the 0310 INSERT check: the property is the
--    caller's, and the parent item/issue is the caller's and on that property.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "evidence_files_update_own" ON public.evidence_files;
CREATE POLICY "evidence_files_update_own" ON public.evidence_files FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.properties p
                 WHERE p.id = evidence_files.property_id AND p.user_id = (auth.user_id())::uuid))
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.properties p
            WHERE p.id = evidence_files.property_id AND p.user_id = (auth.user_id())::uuid)
    AND (evidence_files.inspection_item_id IS NULL OR EXISTS (
      SELECT 1 FROM public.inspection_items ii
      JOIN public.inspections i ON i.id = ii.inspection_id
      WHERE ii.id = evidence_files.inspection_item_id
        AND i.property_id = evidence_files.property_id
        AND i.user_id = (auth.user_id())::uuid))
    AND (evidence_files.maintenance_issue_id IS NULL OR EXISTS (
      SELECT 1 FROM public.maintenance_issues mi
      WHERE mi.id = evidence_files.maintenance_issue_id
        AND mi.property_id = evidence_files.property_id
        AND mi.user_id = (auth.user_id())::uuid))
  );

-- -----------------------------------------------------------------------------
-- 5. dispute_evidence_links: the dispute is the caller's, and the linked evidence /
--    maintenance issue / document is the caller's and on the dispute's property.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "dispute_evidence_links_insert_own" ON public.dispute_evidence_links;
DROP POLICY IF EXISTS "dispute_evidence_links_update_own" ON public.dispute_evidence_links;
CREATE POLICY "dispute_evidence_links_insert_own" ON public.dispute_evidence_links FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.disputes d
    JOIN public.properties p ON p.id = d.property_id
    WHERE d.id = dispute_evidence_links.dispute_id
      AND d.user_id = (auth.user_id())::uuid
      AND p.user_id = (auth.user_id())::uuid
      AND (dispute_evidence_links.evidence_file_id IS NULL OR EXISTS (
        SELECT 1 FROM public.evidence_files ef
        WHERE ef.id = dispute_evidence_links.evidence_file_id AND ef.property_id = d.property_id))
      AND (dispute_evidence_links.maintenance_issue_id IS NULL OR EXISTS (
        SELECT 1 FROM public.maintenance_issues mi
        WHERE mi.id = dispute_evidence_links.maintenance_issue_id
          AND mi.property_id = d.property_id AND mi.user_id = (auth.user_id())::uuid))
      AND (dispute_evidence_links.property_document_id IS NULL OR EXISTS (
        SELECT 1 FROM public.property_documents pd
        WHERE pd.id = dispute_evidence_links.property_document_id
          AND pd.property_id = d.property_id AND pd.user_id = (auth.user_id())::uuid))
  ));
CREATE POLICY "dispute_evidence_links_update_own" ON public.dispute_evidence_links FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.disputes d
                 WHERE d.id = dispute_evidence_links.dispute_id AND d.user_id = (auth.user_id())::uuid))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.disputes d
    JOIN public.properties p ON p.id = d.property_id
    WHERE d.id = dispute_evidence_links.dispute_id
      AND d.user_id = (auth.user_id())::uuid
      AND p.user_id = (auth.user_id())::uuid
      AND (dispute_evidence_links.evidence_file_id IS NULL OR EXISTS (
        SELECT 1 FROM public.evidence_files ef
        WHERE ef.id = dispute_evidence_links.evidence_file_id AND ef.property_id = d.property_id))
      AND (dispute_evidence_links.maintenance_issue_id IS NULL OR EXISTS (
        SELECT 1 FROM public.maintenance_issues mi
        WHERE mi.id = dispute_evidence_links.maintenance_issue_id
          AND mi.property_id = d.property_id AND mi.user_id = (auth.user_id())::uuid))
      AND (dispute_evidence_links.property_document_id IS NULL OR EXISTS (
        SELECT 1 FROM public.property_documents pd
        WHERE pd.id = dispute_evidence_links.property_document_id
          AND pd.property_id = d.property_id AND pd.user_id = (auth.user_id())::uuid))
  ));
