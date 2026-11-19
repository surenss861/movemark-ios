-- =============================================================================
-- 0960 — Role and grant hardening (Production Database Hardening, 2026-10-22)
-- =============================================================================
-- Roles after this migration:
--   anonymous          nothing in public (Data API without a token).
--   authenticated      exactly the table operations the iOS and Android apps perform through the Data
--                      API (inventoried call by call), RLS on top. No billing, dispute, ticket or
--                      checklist-state tables; those are API-only.
--   movemark_backend   NOLOGIN group: DML on the application tables, EXECUTE on the privileged
--                      functions. No ownership, no DDL.
--   movemark_api       LOGIN, member of movemark_backend, BYPASSRLS (the API filters by user itself),
--   movemark_worker    no CREATE anywhere. Separate roles so pg_stat_statements / pg_stat_activity tell
--                      API and worker traffic apart. Passwords are set out-of-band per branch
--                      (scripts/db/runtime_roles.sh), never in a migration.
--   neondb_owner       schema owner; used only by neon/migrate.py, never by Railway at runtime.
--
-- Also: enabling the Data API had set default privileges that grant `authenticated` full DML on every
-- future table (0900 already reversed the same default for functions); new tables are now private until
-- a migration grants them. pg_stat_statements goes into a private schema: in `public` its view would be
-- readable through the Data API, query texts included.
-- =============================================================================

-- 1. Future objects are private by default; the trusted backend group gets DML on new tables.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM authenticated, anonymous, PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM authenticated, anonymous, PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO movemark_backend;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO movemark_backend;

-- 2. Native apps: only what they use (RLS still decides which rows).
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated, anonymous, PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM authenticated, anonymous, PUBLIC;
GRANT SELECT, INSERT, UPDATE         ON public.properties           TO authenticated;
GRANT SELECT, INSERT                 ON public.rooms                TO authenticated;
GRANT SELECT, INSERT                 ON public.inspections          TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.inspection_items     TO authenticated;
GRANT SELECT, INSERT, DELETE         ON public.inspection_item_tags TO authenticated;
GRANT SELECT, INSERT, DELETE         ON public.evidence_files       TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.maintenance_issues   TO authenticated;
GRANT SELECT, INSERT, DELETE         ON public.property_documents   TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.profiles             TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.move_out_checklists  TO authenticated;
GRANT SELECT                         ON public.issue_tags           TO authenticated;
GRANT SELECT                         ON public.exports              TO authenticated;
-- Read-only, own rows (select policies): maintenance_issues_update_own (0930) checks dispute links before
-- an issue may move, and RLS policies run with the caller's privileges. No app writes either table.
GRANT SELECT                         ON public.disputes             TO authenticated;
GRANT SELECT                         ON public.dispute_evidence_links TO authenticated;

-- 3. Backend group: DML on every application table, nothing else.
GRANT USAGE ON SCHEMA public TO movemark_backend;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO movemark_backend;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO movemark_backend;

-- 4. Runtime login roles (one per process kind). Timeouts are role settings, so they hold on every server
--    connection even through PgBouncer transaction pooling, where a session SET does not stick.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'movemark_api') THEN
    CREATE ROLE movemark_api LOGIN BYPASSRLS INHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'movemark_worker') THEN
    CREATE ROLE movemark_worker LOGIN BYPASSRLS INHERIT;
  END IF;
END $$;
GRANT movemark_backend TO movemark_api, movemark_worker;
REVOKE CREATE ON SCHEMA public FROM movemark_api, movemark_worker, PUBLIC;
ALTER ROLE movemark_api    SET timezone = 'UTC';  -- JSON timestamps match the PostgREST-era responses
ALTER ROLE movemark_worker SET timezone = 'UTC';
ALTER ROLE movemark_api    SET statement_timeout = '15s';
ALTER ROLE movemark_api    SET lock_timeout = '5s';
ALTER ROLE movemark_api    SET idle_in_transaction_session_timeout = '15s';
ALTER ROLE movemark_worker SET statement_timeout = '60s';  -- whole-property PDF reads
ALTER ROLE movemark_worker SET lock_timeout = '5s';
ALTER ROLE movemark_worker SET idle_in_transaction_session_timeout = '60s';

-- 5. Account deletion's last step without granting anything on Neon's auth schema: the owner deletes the
--    auth user on the backend's behalf (sessions/accounts and the credit tables cascade from it).
CREATE OR REPLACE FUNCTION public.delete_auth_user(target_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$ DELETE FROM neon_auth."user" WHERE id = target_user_id $$;
REVOKE ALL ON FUNCTION public.delete_auth_user(uuid) FROM PUBLIC, anonymous, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_auth_user(uuid) TO movemark_backend;

-- 6. Privileged functions resolve names in pg_catalog and public only, temporary schemas last.
ALTER FUNCTION public.claim_next_export_job()                    SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION public.reap_stuck_export_jobs(interval, integer)  SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION public.grant_report_credit(uuid, text, text)      SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION public.consume_report_credit(uuid, text)          SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION public.delete_user_owned_data(uuid)               SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION public.get_property_snapshot(uuid)                SET search_path = pg_catalog, public, pg_temp;

-- 7. Query statistics, outside anything the Data API exposes.
CREATE SCHEMA IF NOT EXISTS monitoring;
REVOKE ALL ON SCHEMA monitoring FROM PUBLIC, anonymous, authenticated;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA monitoring;
