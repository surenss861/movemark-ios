-- Rollback of 1059: get_legal_status() answers for auth.user_id() without a null check again (1030's body).
-- Ships as a new forward migration if ever needed, never pasted (see README).
CREATE OR REPLACE FUNCTION public.get_legal_status()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$ SELECT public.legal_status_for_user(nullif(auth.user_id(), '')::uuid) $$;
