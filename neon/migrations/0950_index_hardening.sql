-- =============================================================================
-- 0950 — Indexes proven by query plans (Production Database Hardening, 2026-10-22)
-- =============================================================================
-- Every index here was justified with EXPLAIN (ANALYZE, BUFFERS) on the synthetic dataset from
-- scripts/db/synth_scale.sql (1.65M evidence rows, 1.03M inspection items, 250k rooms; one property
-- with 50k evidence rows) using scripts/db/bench_plans.py. Native-app queries were measured as
-- `authenticated` under RLS. Median local timings, before → after:
--
--   account deletion (delete_user_owned_data)   1983 ms → 10 ms   (571k → 4.9k buffers)
--   upload abandon "is it referenced?" check     1478 ms → 0.06 ms (with exact-match keys, see API)
--   signed-URL lookup by file/thumbnail path      238 ms → 0.04 ms
--   evidence by inspection item                    20 ms → 0.01 ms
--   inspection items by room                       13 ms → 0.01 ms
--   rooms by property (ordered)                   8.6 ms → 0.02 ms
--   property snapshot (typical property)           11 ms → 2.1 ms
--   dispute links by dispute                      1.9 ms → 0.01 ms
--   expired upload-ticket sweep                    19 ms → <0.01 ms
--
-- Foreign keys without an index make every parent DELETE scan the child table (the FK check), which
-- is what made account deletion slow; each FK below now has a leading-column index.
-- Storage paths are matched by equality only, so the hot evidence path indexes are HASH indexes:
-- same lookup cost as B-tree at 102 MB instead of 233 MB for 1.65M rows.
--
-- Not added, deliberately: inspection_item_tags(issue_tag_id) — issue tags are a fixed global list that
-- is never deleted, so its FK check never runs.
-- Candidates to drop later (unused by every benchmarked query; confirm with pg_stat_statements and
-- pg_stat_user_indexes in production before removing): idx_exports_user_id_id,
-- idx_exports_user_prop_dispute_type.
--
-- Plain CREATE INDEX: production holds no rows yet. Future index migrations on populated tables must
-- use CREATE INDEX CONCURRENTLY in their own non-transactional step.
-- =============================================================================

-- Ownership chain: property → room → item → evidence.
CREATE INDEX IF NOT EXISTS rooms_property_sort_idx ON public.rooms (property_id, sort_order);
CREATE INDEX IF NOT EXISTS inspection_items_room_idx ON public.inspection_items (room_id);
CREATE INDEX IF NOT EXISTS evidence_files_item_idx ON public.evidence_files (inspection_item_id)
  WHERE inspection_item_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS evidence_files_maintenance_idx ON public.evidence_files (maintenance_issue_id)
  WHERE maintenance_issue_id IS NOT NULL;

-- Path lookups: signed URLs (apps) and the abandon reference check (API).
CREATE INDEX IF NOT EXISTS evidence_files_file_path_idx ON public.evidence_files USING hash (file_path);
CREATE INDEX IF NOT EXISTS evidence_files_thumbnail_path_idx ON public.evidence_files USING hash (thumbnail_path)
  WHERE thumbnail_path IS NOT NULL;
CREATE INDEX IF NOT EXISTS property_documents_file_path_idx ON public.property_documents USING hash (file_path);
CREATE INDEX IF NOT EXISTS property_documents_thumbnail_path_idx ON public.property_documents USING hash (thumbnail_path)
  WHERE thumbnail_path IS NOT NULL;

-- Disputes and their evidence links (FK checks on evidence/document/maintenance deletes).
CREATE INDEX IF NOT EXISTS disputes_property_idx ON public.disputes (property_id);
CREATE INDEX IF NOT EXISTS disputes_user_idx ON public.disputes (user_id);
CREATE INDEX IF NOT EXISTS dispute_links_dispute_idx ON public.dispute_evidence_links (dispute_id);
CREATE INDEX IF NOT EXISTS dispute_links_evidence_idx ON public.dispute_evidence_links (evidence_file_id)
  WHERE evidence_file_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS dispute_links_maintenance_idx ON public.dispute_evidence_links (maintenance_issue_id)
  WHERE maintenance_issue_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS dispute_links_document_idx ON public.dispute_evidence_links (property_document_id)
  WHERE property_document_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS exports_dispute_idx ON public.exports (dispute_id) WHERE dispute_id IS NOT NULL;

-- Account deletion filters these by user_id, which is not their leading index column.
CREATE INDEX IF NOT EXISTS inspections_user_idx ON public.inspections (user_id);
CREATE INDEX IF NOT EXISTS maintenance_issues_user_idx ON public.maintenance_issues (user_id);
CREATE INDEX IF NOT EXISTS property_documents_user_idx ON public.property_documents (user_id);

-- Sweep of upload tickets that were never finalized/consumed (see 0960's sweeper function).
CREATE INDEX IF NOT EXISTS storage_upload_tickets_open_expiry_idx ON public.storage_upload_tickets (expires_at)
  WHERE state IN ('issued', 'finalized');

