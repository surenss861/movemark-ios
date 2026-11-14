-- =============================================================================
-- 1061: get_legal_status() refuses a request without a user id instead of answering for nobody.
--
-- Found 2026-11-13 (Android 1.4.0 on a Galaxy A14, P1): after accepting, a cold start showed the agreement again.
-- 1030 defined get_legal_status() as legal_status_for_user(nullif(auth.user_id(), '')::uuid) with no null check.
-- When a Data API request carries a valid token but auth.user_id() is momentarily null (the dev rehearsal saw this
-- as a one-off LEGAL_NOT_AUTHENTICATED from accept on a valid token), the status is computed for a NULL user:
-- documents published, no acceptance, so `acceptance_required: true`. An unknown identity was read as "this account
-- hasn't agreed". accept_legal_documents already refuses that case; this makes the status call do the same.
--
-- Change: the function body only. Same signature, return type, SECURITY DEFINER, search_path and grants
-- (CREATE OR REPLACE keeps them). The language becomes plpgsql so it can raise. legal_status_for_user(uuid) is
-- unchanged: only movemark_api calls it, with the id of an already verified token.
--
-- Client impact: Android 1.4 (42ff213+) and iOS 1.4 retry LEGAL_NOT_AUTHENTICATED once, then show "Can't open your
-- Vault yet" with Try again, never the agreement. Android 1.4.0 2026111301 treats the error as "no answer" and opens
-- the app (enforcement is off). Nothing is enforced or recorded by this migration.
--
-- Rollback: rollback/1061_legal_status_requires_identity.down.sql (restores 1030's body).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_legal_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  caller uuid := nullif(auth.user_id(), '')::uuid;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'LEGAL_NOT_AUTHENTICATED' USING ERRCODE = '42501';
  END IF;
  RETURN public.legal_status_for_user(caller);
END;
$$;
