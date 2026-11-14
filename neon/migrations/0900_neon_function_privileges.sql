-- =============================================================================
-- 0900 — Function privileges on Neon (new, 2026-10-20)
-- =============================================================================
-- Enabling the Neon Data API sets
--   ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA public
--     GRANT EXECUTE ON FUNCTIONS TO authenticated;
-- so every function the migrations create became callable by any signed-in user
-- through the Data API (POST /rpc/...). The tracked migrations only revoked from
-- PUBLIC, which was sufficient on Supabase. Without this file, any user could call
-- delete_user_owned_data(<someone else's id>) or grant_report_credit(<self>).
--
-- Functions are now opt-in: only get_property_snapshot is client-callable.
-- =============================================================================

REVOKE EXECUTE ON FUNCTION public.claim_next_export_job()                       FROM authenticated, anonymous, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.reap_stuck_export_jobs(interval, integer)     FROM authenticated, anonymous, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.grant_report_credit(uuid, text, text)         FROM authenticated, anonymous, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.consume_report_credit(uuid, text)             FROM authenticated, anonymous, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.delete_user_owned_data(uuid)                  FROM authenticated, anonymous, PUBLIC;

-- Snapshot stays callable by signed-in users only (SECURITY INVOKER, so RLS applies).
REVOKE EXECUTE ON FUNCTION public.get_property_snapshot(uuid) FROM PUBLIC, anonymous;
GRANT  EXECUTE ON FUNCTION public.get_property_snapshot(uuid) TO authenticated;

-- Future functions are not client-callable unless a migration grants them explicitly.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
