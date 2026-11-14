-- =============================================================================
-- 0970 — Runtime least privilege: no BYPASSRLS, per-process grants, explicit backend row access
-- (Production Database Hardening, P0 review, 2026-10-22)
-- =============================================================================
-- 0960 took the API and worker off the schema owner but gave both login roles BYPASSRLS and the shared
-- group DML on every table (and, by default privileges, on every future table). This narrows that:
--
--   * BYPASSRLS is removed. A role attribute applies to every table, present and future; instead each
--     table a runtime role may touch gets an explicit, named policy for that role only. A table without
--     such a policy stays closed to it even if a grant is added by mistake (RLS is enabled everywhere).
--   * Grants are per process, from the code inventory (scripts verified by running the full API suite as
--     movemark_api and the worker suites as movemark_worker):
--       movemark_worker  reads the property data a PDF needs; updates exports (claim lease, heartbeat,
--                        outcome); settles expired upload tickets (sweeper). Nothing else.
--     Each uncertain grant was checked by revoking it and rerunning the suites, then against the code;
--     unused ones (API: profiles; worker: disputes, dispute links) were dropped.
--       movemark_api     reads what its endpoints serve; inserts exports (enqueue), manages upload
--                        tickets, upserts entitlements (RevenueCat webhook), deletes evidence/document/link
--                        rows (storage delete endpoint). Credits, account deletion and the export queue's
--                        claim/reap only through their SECURITY DEFINER functions.
--   * movemark_backend keeps only EXECUTE on the privileged functions (granted per function in 0900/0960);
--     its table DML from 0960 and its default privilege on future tables are revoked: new tables are
--     private to every role until a migration grants them.
--   * Neither runtime role owns anything, holds a grant option, has CREATE on the database or a schema,
--     or can SET ROLE to the owner; tests in neon/tests/test_reconstruction.py prove each of these.
-- =============================================================================

ALTER ROLE movemark_api NOBYPASSRLS;
ALTER ROLE movemark_worker NOBYPASSRLS;

-- Future functions: PostgreSQL grants EXECUTE on every new function to PUBLIC *globally*, and per-schema
-- default privileges can only add to the global ones — so 0900's
-- "ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC" never took effect
-- (every existing function is safe only because 0900 also revoked each one explicitly). Revoke it globally
-- for the migration role, so a function added by a future migration is callable by nobody until granted.
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Undo 0960's blanket backend grants (tables, sequences, future tables).
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM movemark_backend;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM movemark_backend;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM movemark_backend;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM movemark_backend;
DO $$ BEGIN EXECUTE format('REVOKE CREATE ON DATABASE %I FROM PUBLIC', current_database()); END $$;  -- no new schemas

-- Worker: PDF inputs (read), export outcome, ticket sweep.
GRANT SELECT ON public.properties, public.rooms, public.inspections, public.inspection_items,
                public.inspection_item_tags, public.issue_tags, public.evidence_files, public.property_documents,
                public.maintenance_issues
  TO movemark_worker;
GRANT SELECT, UPDATE ON public.exports, public.storage_upload_tickets TO movemark_worker;

-- API.
GRANT SELECT ON public.properties, public.rooms, public.inspections, public.inspection_items,
                public.inspection_item_tags, public.issue_tags, public.maintenance_issues, public.disputes,
                public.user_report_credits
  TO movemark_api;
GRANT SELECT, DELETE ON public.evidence_files, public.property_documents, public.dispute_evidence_links TO movemark_api;
GRANT SELECT, INSERT ON public.exports TO movemark_api;
GRANT SELECT, INSERT, UPDATE ON public.user_entitlements TO movemark_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.storage_upload_tickets TO movemark_api;

-- Explicit row access for exactly those tables: the backend serves every user and filters by the
-- authenticated user itself, so each policy admits all rows — but only for that role, on that table.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['properties','rooms','inspections','inspection_items','inspection_item_tags','issue_tags',
                           'evidence_files','property_documents','maintenance_issues','exports',
                           'storage_upload_tickets'] LOOP
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO movemark_worker USING (true) WITH CHECK (true)',
                   t || '_worker_rows', t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['properties','rooms','inspections','inspection_items','inspection_item_tags','issue_tags',
                           'evidence_files','property_documents','maintenance_issues','disputes',
                           'dispute_evidence_links','exports','storage_upload_tickets','user_entitlements',
                           'user_report_credits'] LOOP
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO movemark_api USING (true) WITH CHECK (true)',
                   t || '_api_rows', t);
  END LOOP;
END $$;
