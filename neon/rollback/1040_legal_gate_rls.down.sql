-- Undoes 1040. Acceptances, documents and the switch stay; only enforcement on the Data API goes.
-- Migrations are forward-only: on a ledgered branch this body ships as the next numbered migration, through
-- the runner. Never paste it into a database.
DROP POLICY IF EXISTS properties_legal_gate ON public.properties;
DROP POLICY IF EXISTS rooms_legal_gate ON public.rooms;
DROP POLICY IF EXISTS inspections_legal_gate ON public.inspections;
DROP POLICY IF EXISTS inspection_items_legal_gate ON public.inspection_items;
DROP POLICY IF EXISTS evidence_files_legal_gate ON public.evidence_files;
DROP POLICY IF EXISTS property_documents_legal_gate ON public.property_documents;
DROP POLICY IF EXISTS exports_legal_gate ON public.exports;
-- Exactly as 0930 left it. The gate policy above had to go first: with it in place this expansion recurses.
CREATE POLICY "inspections_update_own" ON public.inspections FOR UPDATE TO authenticated
  USING (user_id = (auth.user_id())::uuid)
  WITH CHECK (user_id = (auth.user_id())::uuid
              AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = inspections.property_id AND p.user_id = (auth.user_id())::uuid)
              -- moving an inspection must not strand its items (or their evidence) on another property
              AND NOT EXISTS (SELECT 1 FROM public.inspection_items ii JOIN public.rooms r ON r.id = ii.room_id
                              WHERE ii.inspection_id = inspections.id AND r.property_id <> inspections.property_id)
              AND NOT EXISTS (SELECT 1 FROM public.inspection_items ii JOIN public.evidence_files ef ON ef.inspection_item_id = ii.id
                              WHERE ii.inspection_id = inspections.id AND ef.property_id <> inspections.property_id));
