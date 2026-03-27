-- MoveMark production: RLS policies for direct user_id ownership
-- DROP IF EXISTS so re-run is safe when policies already exist.

-- profiles: own row only (id = auth.uid())
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- properties
DROP POLICY IF EXISTS "properties_select_own" ON public.properties;
DROP POLICY IF EXISTS "properties_insert_own" ON public.properties;
DROP POLICY IF EXISTS "properties_update_own" ON public.properties;
DROP POLICY IF EXISTS "properties_delete_own" ON public.properties;
CREATE POLICY "properties_select_own" ON public.properties FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "properties_insert_own" ON public.properties FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "properties_update_own" ON public.properties FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "properties_delete_own" ON public.properties FOR DELETE USING (auth.uid() = user_id);

-- inspections
DROP POLICY IF EXISTS "inspections_select_own" ON public.inspections;
DROP POLICY IF EXISTS "inspections_insert_own" ON public.inspections;
DROP POLICY IF EXISTS "inspections_update_own" ON public.inspections;
DROP POLICY IF EXISTS "inspections_delete_own" ON public.inspections;
CREATE POLICY "inspections_select_own" ON public.inspections FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "inspections_insert_own" ON public.inspections FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "inspections_update_own" ON public.inspections FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "inspections_delete_own" ON public.inspections FOR DELETE USING (auth.uid() = user_id);

-- maintenance_issues
DROP POLICY IF EXISTS "maintenance_select_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_insert_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_update_own" ON public.maintenance_issues;
DROP POLICY IF EXISTS "maintenance_delete_own" ON public.maintenance_issues;
CREATE POLICY "maintenance_select_own" ON public.maintenance_issues FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "maintenance_insert_own" ON public.maintenance_issues FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "maintenance_update_own" ON public.maintenance_issues FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "maintenance_delete_own" ON public.maintenance_issues FOR DELETE USING (auth.uid() = user_id);

-- property_documents
DROP POLICY IF EXISTS "property_documents_select_own" ON public.property_documents;
DROP POLICY IF EXISTS "property_documents_insert_own" ON public.property_documents;
DROP POLICY IF EXISTS "property_documents_update_own" ON public.property_documents;
DROP POLICY IF EXISTS "property_documents_delete_own" ON public.property_documents;
CREATE POLICY "property_documents_select_own" ON public.property_documents FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "property_documents_insert_own" ON public.property_documents FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "property_documents_update_own" ON public.property_documents FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "property_documents_delete_own" ON public.property_documents FOR DELETE USING (auth.uid() = user_id);

-- move_out_checklists
DROP POLICY IF EXISTS "move_out_checklists_select_own" ON public.move_out_checklists;
DROP POLICY IF EXISTS "move_out_checklists_insert_own" ON public.move_out_checklists;
DROP POLICY IF EXISTS "move_out_checklists_update_own" ON public.move_out_checklists;
DROP POLICY IF EXISTS "move_out_checklists_delete_own" ON public.move_out_checklists;
CREATE POLICY "move_out_checklists_select_own" ON public.move_out_checklists FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "move_out_checklists_insert_own" ON public.move_out_checklists FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "move_out_checklists_update_own" ON public.move_out_checklists FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "move_out_checklists_delete_own" ON public.move_out_checklists FOR DELETE USING (auth.uid() = user_id);

-- move_out_checklist_state
DROP POLICY IF EXISTS "move_out_checklist_state_select_own" ON public.move_out_checklist_state;
DROP POLICY IF EXISTS "move_out_checklist_state_insert_own" ON public.move_out_checklist_state;
DROP POLICY IF EXISTS "move_out_checklist_state_update_own" ON public.move_out_checklist_state;
DROP POLICY IF EXISTS "move_out_checklist_state_delete_own" ON public.move_out_checklist_state;
CREATE POLICY "move_out_checklist_state_select_own" ON public.move_out_checklist_state FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "move_out_checklist_state_insert_own" ON public.move_out_checklist_state FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "move_out_checklist_state_update_own" ON public.move_out_checklist_state FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "move_out_checklist_state_delete_own" ON public.move_out_checklist_state FOR DELETE USING (auth.uid() = user_id);

-- disputes
DROP POLICY IF EXISTS "disputes_select_own" ON public.disputes;
DROP POLICY IF EXISTS "disputes_insert_own" ON public.disputes;
DROP POLICY IF EXISTS "disputes_update_own" ON public.disputes;
DROP POLICY IF EXISTS "disputes_delete_own" ON public.disputes;
CREATE POLICY "disputes_select_own" ON public.disputes FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "disputes_insert_own" ON public.disputes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "disputes_update_own" ON public.disputes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "disputes_delete_own" ON public.disputes FOR DELETE USING (auth.uid() = user_id);

-- exports
DROP POLICY IF EXISTS "exports_select_own" ON public.exports;
DROP POLICY IF EXISTS "exports_insert_own" ON public.exports;
DROP POLICY IF EXISTS "exports_update_own" ON public.exports;
DROP POLICY IF EXISTS "exports_delete_own" ON public.exports;
CREATE POLICY "exports_select_own" ON public.exports FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "exports_insert_own" ON public.exports FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "exports_update_own" ON public.exports FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "exports_delete_own" ON public.exports FOR DELETE USING (auth.uid() = user_id);
