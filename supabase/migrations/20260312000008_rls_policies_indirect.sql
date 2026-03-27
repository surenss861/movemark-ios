-- MoveMark production: RLS policies for indirect ownership (via property / inspection / dispute)
-- DROP IF EXISTS so re-run is safe when policies already exist.

-- rooms: ownership via property
DROP POLICY IF EXISTS "rooms_select_via_property" ON public.rooms;
DROP POLICY IF EXISTS "rooms_insert_via_property" ON public.rooms;
DROP POLICY IF EXISTS "rooms_update_via_property" ON public.rooms;
DROP POLICY IF EXISTS "rooms_delete_via_property" ON public.rooms;
CREATE POLICY "rooms_select_via_property" ON public.rooms FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = rooms.property_id AND p.user_id = auth.uid()));
CREATE POLICY "rooms_insert_via_property" ON public.rooms FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = rooms.property_id AND p.user_id = auth.uid()));
CREATE POLICY "rooms_update_via_property" ON public.rooms FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = rooms.property_id AND p.user_id = auth.uid()));
CREATE POLICY "rooms_delete_via_property" ON public.rooms FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = rooms.property_id AND p.user_id = auth.uid()));

-- inspection_items: ownership via inspection
DROP POLICY IF EXISTS "inspection_items_select_via_inspection" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_insert_via_inspection" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_update_via_inspection" ON public.inspection_items;
DROP POLICY IF EXISTS "inspection_items_delete_via_inspection" ON public.inspection_items;
CREATE POLICY "inspection_items_select_via_inspection" ON public.inspection_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.inspections i WHERE i.id = inspection_items.inspection_id AND i.user_id = auth.uid()));
CREATE POLICY "inspection_items_insert_via_inspection" ON public.inspection_items FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.inspections i WHERE i.id = inspection_items.inspection_id AND i.user_id = auth.uid()));
CREATE POLICY "inspection_items_update_via_inspection" ON public.inspection_items FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.inspections i WHERE i.id = inspection_items.inspection_id AND i.user_id = auth.uid()));
CREATE POLICY "inspection_items_delete_via_inspection" ON public.inspection_items FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.inspections i WHERE i.id = inspection_items.inspection_id AND i.user_id = auth.uid()));

-- evidence_files: ownership via property + (inspection_item -> inspection or maintenance_issue)
DROP POLICY IF EXISTS "evidence_files_select_own" ON public.evidence_files;
DROP POLICY IF EXISTS "evidence_files_insert_own" ON public.evidence_files;
DROP POLICY IF EXISTS "evidence_files_update_own" ON public.evidence_files;
DROP POLICY IF EXISTS "evidence_files_delete_own" ON public.evidence_files;
CREATE POLICY "evidence_files_select_own" ON public.evidence_files FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.properties p WHERE p.id = evidence_files.property_id AND p.user_id = auth.uid())
    AND (
      (evidence_files.inspection_item_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.inspection_items ii
        JOIN public.inspections i ON i.id = ii.inspection_id
        WHERE ii.id = evidence_files.inspection_item_id AND i.user_id = auth.uid()
      ))
      OR
      (evidence_files.maintenance_issue_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.maintenance_issues m
        WHERE m.id = evidence_files.maintenance_issue_id AND m.user_id = auth.uid()
      ))
    )
  );
CREATE POLICY "evidence_files_insert_own" ON public.evidence_files FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.properties p WHERE p.id = evidence_files.property_id AND p.user_id = auth.uid())
    AND (
      (evidence_files.inspection_item_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.inspection_items ii
        JOIN public.inspections i ON i.id = ii.inspection_id
        WHERE ii.id = evidence_files.inspection_item_id AND i.user_id = auth.uid()
      ))
      OR
      (evidence_files.maintenance_issue_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.maintenance_issues m
        WHERE m.id = evidence_files.maintenance_issue_id AND m.user_id = auth.uid()
      ))
    )
  );
CREATE POLICY "evidence_files_update_own" ON public.evidence_files FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.properties p WHERE p.id = evidence_files.property_id AND p.user_id = auth.uid())
  );
CREATE POLICY "evidence_files_delete_own" ON public.evidence_files FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.properties p WHERE p.id = evidence_files.property_id AND p.user_id = auth.uid())
  );

-- issue_tags: read-only for authenticated (seeded / admin-managed)
DROP POLICY IF EXISTS "issue_tags_select_authenticated" ON public.issue_tags;
CREATE POLICY "issue_tags_select_authenticated" ON public.issue_tags FOR SELECT TO authenticated USING (true);

-- inspection_item_tags: ownership via inspection_item -> inspection
DROP POLICY IF EXISTS "inspection_item_tags_select_via_item" ON public.inspection_item_tags;
DROP POLICY IF EXISTS "inspection_item_tags_insert_via_item" ON public.inspection_item_tags;
DROP POLICY IF EXISTS "inspection_item_tags_delete_via_item" ON public.inspection_item_tags;
CREATE POLICY "inspection_item_tags_select_via_item" ON public.inspection_item_tags FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.inspection_items ii
    JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE ii.id = inspection_item_tags.inspection_item_id AND i.user_id = auth.uid()
  ));
CREATE POLICY "inspection_item_tags_insert_via_item" ON public.inspection_item_tags FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.inspection_items ii
    JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE ii.id = inspection_item_tags.inspection_item_id AND i.user_id = auth.uid()
  ));
CREATE POLICY "inspection_item_tags_delete_via_item" ON public.inspection_item_tags FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM public.inspection_items ii
    JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE ii.id = inspection_item_tags.inspection_item_id AND i.user_id = auth.uid()
  ));

-- dispute_evidence_links: ownership via dispute
DROP POLICY IF EXISTS "dispute_evidence_links_select_via_dispute" ON public.dispute_evidence_links;
DROP POLICY IF EXISTS "dispute_evidence_links_insert_via_dispute" ON public.dispute_evidence_links;
DROP POLICY IF EXISTS "dispute_evidence_links_update_via_dispute" ON public.dispute_evidence_links;
DROP POLICY IF EXISTS "dispute_evidence_links_delete_via_dispute" ON public.dispute_evidence_links;
CREATE POLICY "dispute_evidence_links_select_via_dispute" ON public.dispute_evidence_links FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.disputes d WHERE d.id = dispute_evidence_links.dispute_id AND d.user_id = auth.uid()));
CREATE POLICY "dispute_evidence_links_insert_via_dispute" ON public.dispute_evidence_links FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.disputes d WHERE d.id = dispute_evidence_links.dispute_id AND d.user_id = auth.uid()));
CREATE POLICY "dispute_evidence_links_update_via_dispute" ON public.dispute_evidence_links FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.disputes d WHERE d.id = dispute_evidence_links.dispute_id AND d.user_id = auth.uid()));
CREATE POLICY "dispute_evidence_links_delete_via_dispute" ON public.dispute_evidence_links FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.disputes d WHERE d.id = dispute_evidence_links.dispute_id AND d.user_id = auth.uid()));
