-- Rollback of 1055 (age attestation). Ships as the next numbered migration, never pasted (see README).
-- Restores the 1030 definitions; acceptances keep their rows, the attestation columns go. Recorded attestations
-- are lost, so export them first if a lawyer wants them kept.

DROP FUNCTION public.accept_legal_documents(text, text, text, text);

CREATE OR REPLACE FUNCTION public.legal_user_has_current_acceptance(target_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.legal_acceptances a
    JOIN public.legal_documents t ON t.kind = 'terms' AND t.active AND t.version = a.terms_version
    JOIN public.legal_documents p ON p.kind = 'privacy_notice' AND p.active AND p.version = a.privacy_notice_version
    WHERE a.user_id = target_user_id)
$$;

CREATE OR REPLACE FUNCTION public.legal_status_for_user(target_user_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
  WITH active AS (
    SELECT d.kind, jsonb_build_object('version', d.version, 'content_hash', d.content_hash, 'url', d.url,
                                      'is_final', d.is_final, 'published_at', d.published_at) AS doc
    FROM public.legal_documents d WHERE d.active
  ), facts AS (
    SELECT (SELECT s.enforced FROM public.legal_gate_settings s) AS enforced,
           (SELECT count(*) FROM active) = 2 AS published,
           public.legal_user_has_current_acceptance(target_user_id) AS accepted
  )
  SELECT jsonb_build_object(
    'enforced', f.enforced,
    'acceptance_required', f.published AND NOT f.accepted,
    'blocked', f.enforced AND f.published AND NOT f.accepted,
    'documents', CASE WHEN f.published
                      THEN (SELECT jsonb_object_agg(a.kind, a.doc) FROM active a) END,
    'accepted', (SELECT jsonb_build_object('terms_version', x.terms_version,
                                           'privacy_notice_version', x.privacy_notice_version,
                                           'accepted_at', x.accepted_at,
                                           'acceptance_method', x.acceptance_method)
                 FROM public.legal_acceptances x
                 JOIN public.legal_documents t ON t.kind = 'terms' AND t.active AND t.version = x.terms_version
                 JOIN public.legal_documents p ON p.kind = 'privacy_notice' AND p.active AND p.version = x.privacy_notice_version
                 WHERE x.user_id = target_user_id))
  FROM facts f
$$;

CREATE OR REPLACE FUNCTION public.accept_legal_documents(p_method text, p_terms_version text, p_privacy_notice_version text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  caller uuid := nullif(auth.user_id(), '')::uuid;
  terms public.legal_documents%ROWTYPE;
  notice public.legal_documents%ROWTYPE;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'LEGAL_NOT_AUTHENTICATED' USING ERRCODE = '42501';
  END IF;
  IF p_method IS NULL OR p_method NOT IN ('email', 'apple', 'google') THEN
    RAISE EXCEPTION 'LEGAL_INVALID_METHOD' USING ERRCODE = '22023';
  END IF;

  -- FOR SHARE: publishing a new version waits for this acceptance, or this one sees the new version.
  SELECT * INTO terms FROM public.legal_documents d WHERE d.kind = 'terms' AND d.active FOR SHARE;
  SELECT * INTO notice FROM public.legal_documents d WHERE d.kind = 'privacy_notice' AND d.active FOR SHARE;
  IF terms.id IS NULL OR notice.id IS NULL THEN
    RAISE EXCEPTION 'LEGAL_DOCUMENTS_UNAVAILABLE' USING ERRCODE = '22023';
  END IF;
  IF p_terms_version IS DISTINCT FROM terms.version OR p_privacy_notice_version IS DISTINCT FROM notice.version THEN
    RAISE EXCEPTION 'LEGAL_VERSION_NOT_ACTIVE' USING ERRCODE = '22023',
      DETAIL = format('active terms %s, privacy notice %s', terms.version, notice.version);
  END IF;

  INSERT INTO public.legal_acceptances (user_id, terms_version, privacy_notice_version, acceptance_method, document_hashes)
  VALUES (caller, terms.version, notice.version, p_method,
          jsonb_build_object('terms', terms.content_hash, 'privacy_notice', notice.content_hash))
  ON CONFLICT (user_id, terms_version, privacy_notice_version) DO NOTHING;

  RETURN public.legal_status_for_user(caller);
END;
$$;

ALTER TABLE public.legal_acceptances
  DROP CONSTRAINT legal_acceptances_age_attested_together,
  DROP COLUMN age_attestation,
  DROP COLUMN age_attested_at;
ALTER TABLE public.legal_gate_settings DROP COLUMN age_requirement;
