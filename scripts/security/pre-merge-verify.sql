-- MoveMark security verification — READ ONLY.
--
-- Run against a Neon branch as its owner before merging security-relevant changes:
--   psql "$BRANCH_DSN" -f scripts/security/pre-merge-verify.sql
-- Everything runs in a READ ONLY transaction: Postgres refuses any write, so this file can
-- only report. Schema changes belong in neon/migrations (the old version of this file ran
-- ALTER TABLE in "Step 1"; that is now migration 0280).
-- The authoritative gates are neon/tests (local) and neon_owner_gate.sql / data_api_e2e.py
-- (real branch); this is a quick human-readable summary.

BEGIN TRANSACTION READ ONLY;

-- 1. Export status constraint includes the worker's states.
SELECT 'exports_status_check' AS check, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.exports'::regclass AND conname = 'exports_status_check';

-- 2. RLS is enabled on every public table. Expected: no rows.
SELECT c.relname AS table_without_rls
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity;

-- 3. Policy count per table (a table with RLS and no policy is closed to clients — fine for
--    backend-only tables such as storage_upload_tickets).
SELECT tablename, count(*) AS policy_count
FROM pg_policies WHERE schemaname = 'public'
GROUP BY tablename ORDER BY tablename;

-- 4. Policies that are open to everyone. Expected: only issue_tags SELECT (global tag list).
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND (qual = 'true' OR with_check = 'true');

-- 5a. Client write privileges revoked outright (0920, 0930). Expected: no rows.
SELECT table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND grantee IN ('authenticated', 'anonymous')
  AND table_name IN ('exports', 'storage_upload_tickets')
  AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE');

-- 5b. Client write policies on backend-only tables (credits, entitlements, exports, tickets).
--     RLS with no write policy denies clients. Expected: no rows.
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('exports', 'storage_upload_tickets', 'user_report_credits',
                    'report_credit_events', 'user_entitlements')
  AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL');

-- 6. Functions clients can call over /rpc (0900). Expected: get_property_snapshot only.
SELECT routine_name, grantee
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public' AND grantee IN ('authenticated', 'anonymous', 'PUBLIC')
ORDER BY routine_name;

-- 7. Policy definitions, for review: ownership via (auth.user_id())::uuid, parents checked
--    on INSERT and UPDATE (0930).
SELECT tablename, policyname, cmd, permissive, qual, with_check
FROM pg_policies WHERE schemaname = 'public'
ORDER BY tablename, cmd, policyname;

ROLLBACK;
