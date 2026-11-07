-- Undoes 1050. Same rule as the others: ships as the next numbered migration, through the runner.
DROP POLICY IF EXISTS maintenance_issues_legal_gate ON public.maintenance_issues;
DROP POLICY IF EXISTS inspection_item_tags_legal_gate ON public.inspection_item_tags;
DROP POLICY IF EXISTS move_out_checklists_legal_gate ON public.move_out_checklists;
DROP POLICY IF EXISTS move_out_checklist_state_legal_gate ON public.move_out_checklist_state;
DROP POLICY IF EXISTS disputes_legal_gate ON public.disputes;
DROP POLICY IF EXISTS dispute_evidence_links_legal_gate ON public.dispute_evidence_links;
-- Exactly as 0930 left it. The gate policies above had to go first.
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
