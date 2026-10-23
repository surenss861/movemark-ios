-- =============================================================================
-- 1010 — movemark_backup: the scheduled off-site backup's database role (Gate 3A; approved exception to
-- the schema freeze at 1000).
--
-- pg_dump must read every renter's rows, so the role bypasses RLS — and that is all it can do:
--   * reads through pg_read_all_data (SELECT on every table and sequence, USAGE on every schema), granted
--     WITH INHERIT so pg_dump gets it without SET ROLE, and WITH SET FALSE;
--   * no INSERT/UPDATE/DELETE/TRUNCATE anywhere, no CREATE in any schema, owns nothing, belongs to no
--     MoveMark group (movemark_backend, the API/worker roles), executes no application function;
--   * one connection at a time; sessions default to read-only with bounded timeouts (pg_dump lifts the
--     statement and idle timeouts for its own run, which is why the privileges, not the settings, are
--     the guarantee).
-- Its password is set outside migrations (scripts/db/runtime_roles.py) and lives only in the separate
-- Railway backup service — never with the API or the worker.
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'movemark_backup') THEN
    CREATE ROLE movemark_backup LOGIN BYPASSRLS NOINHERIT;
  END IF;
END $$;
ALTER ROLE movemark_backup LOGIN BYPASSRLS NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION CONNECTION LIMIT 1;

GRANT pg_read_all_data TO movemark_backup WITH INHERIT TRUE, SET FALSE;

ALTER ROLE movemark_backup SET default_transaction_read_only = on;
ALTER ROLE movemark_backup SET timezone = 'UTC';
ALTER ROLE movemark_backup SET statement_timeout = '15min';
ALTER ROLE movemark_backup SET lock_timeout = '30s';
ALTER ROLE movemark_backup SET idle_in_transaction_session_timeout = '5min';
