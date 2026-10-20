-- =============================================================================
-- 0000 — Neon platform roles (new for the Neon recovery, 2026-10-20)
-- =============================================================================
-- Provided by Neon, NOT created here:
--   * role `authenticated` — the Data API switches to it for a valid Neon Auth JWT
--   * role `anonymous`     — unauthenticated Data API requests (granted nothing)
--   * auth.user_id()       — returns the JWT `sub` (text; Neon Auth ids are UUIDs)
--   * schema neon_auth     — Managed Better Auth users and sessions
--
-- Created here:
--   * role `movemark_backend` — replaces Supabase `service_role` semantics: the
--     functions only the trusted Railway API/worker may call (export queue,
--     credits, account deletion). The Railway login role is made a member of it.
--     Railway connects as the table owner, so RLS does not apply to it (same
--     effect as service_role, without BYPASSRLS).
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'movemark_backend') THEN
    CREATE ROLE movemark_backend NOLOGIN;
  END IF;
END
$$;

-- Data API access to the public schema; RLS (enabled by the replayed migrations)
-- decides which rows. Equivalent to Supabase's default grants to `authenticated`.
GRANT USAGE ON SCHEMA public TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO authenticated;
