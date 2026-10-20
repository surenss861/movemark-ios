-- LOCAL TESTING ONLY. Stand-ins for objects Neon provides itself (never apply to Neon):
--   roles authenticated/anonymous, auth.user_id(), neon_auth."user".
-- auth.user_id() reads the test's simulated JWT claims, as Neon's Data API does per request.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anonymous') THEN CREATE ROLE anonymous NOLOGIN; END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.user_id() RETURNS text LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('request.jwt.claims', true), '')::json ->> 'sub' $$;
GRANT USAGE ON SCHEMA auth TO authenticated, anonymous;
GRANT EXECUTE ON FUNCTION auth.user_id() TO authenticated, anonymous;
CREATE SCHEMA IF NOT EXISTS neon_auth;
CREATE TABLE IF NOT EXISTS neon_auth."user" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE,
  name text,
  "createdAt" timestamptz NOT NULL DEFAULT now()
);

-- Reproduce Neon's Data API defaults (observed on the real project, 2026-10-20):
-- every function created in public is executable by `authenticated` unless revoked.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;
