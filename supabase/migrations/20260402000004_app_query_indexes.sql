-- Indexes aligned with common app queries (ownership + parent IDs).
-- Idempotent: safe to re-run.

CREATE INDEX IF NOT EXISTS idx_property_documents_prop_user_type
  ON public.property_documents (property_id, user_id, document_type);

CREATE INDEX IF NOT EXISTS idx_evidence_files_prop_item_maint
  ON public.evidence_files (property_id, inspection_item_id, maintenance_issue_id);

CREATE INDEX IF NOT EXISTS idx_inspection_items_insp_room
  ON public.inspection_items (inspection_id, room_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_issues_prop_user_status
  ON public.maintenance_issues (property_id, user_id, status);

CREATE INDEX IF NOT EXISTS idx_exports_user_prop_dispute_type
  ON public.exports (user_id, property_id, dispute_id, export_type);
