-- Indexes aligned with common app queries. Each statement runs only if the target table exists.

DO $idx_property_documents$
BEGIN
  IF to_regclass('public.property_documents') IS NULL THEN
    RAISE NOTICE 'movemark idx: skipped idx_property_documents_prop_user_type (table missing)';
    RETURN;
  END IF;
  EXECUTE $sql$
    CREATE INDEX IF NOT EXISTS idx_property_documents_prop_user_type
      ON public.property_documents (property_id, user_id, document_type)
  $sql$;
END
$idx_property_documents$;

DO $idx_evidence_files$
BEGIN
  IF to_regclass('public.evidence_files') IS NULL THEN
    RAISE NOTICE 'movemark idx: skipped idx_evidence_files_prop_item_maint (table missing)';
    RETURN;
  END IF;
  EXECUTE $sql$
    CREATE INDEX IF NOT EXISTS idx_evidence_files_prop_item_maint
      ON public.evidence_files (property_id, inspection_item_id, maintenance_issue_id)
  $sql$;
END
$idx_evidence_files$;

DO $idx_inspection_items$
BEGIN
  IF to_regclass('public.inspection_items') IS NULL THEN
    RAISE NOTICE 'movemark idx: skipped idx_inspection_items_insp_room (table missing)';
    RETURN;
  END IF;
  EXECUTE $sql$
    CREATE INDEX IF NOT EXISTS idx_inspection_items_insp_room
      ON public.inspection_items (inspection_id, room_id)
  $sql$;
END
$idx_inspection_items$;

DO $idx_maintenance_issues$
BEGIN
  IF to_regclass('public.maintenance_issues') IS NULL THEN
    RAISE NOTICE 'movemark idx: skipped idx_maintenance_issues_prop_user_status (table missing)';
    RETURN;
  END IF;
  EXECUTE $sql$
    CREATE INDEX IF NOT EXISTS idx_maintenance_issues_prop_user_status
      ON public.maintenance_issues (property_id, user_id, status)
  $sql$;
END
$idx_maintenance_issues$;

DO $idx_exports$
BEGIN
  IF to_regclass('public.exports') IS NULL THEN
    RAISE NOTICE 'movemark idx: skipped idx_exports_user_prop_dispute_type (table missing)';
    RETURN;
  END IF;
  EXECUTE $sql$
    CREATE INDEX IF NOT EXISTS idx_exports_user_prop_dispute_type
      ON public.exports (user_id, property_id, dispute_id, export_type)
  $sql$;
END
$idx_exports$;
