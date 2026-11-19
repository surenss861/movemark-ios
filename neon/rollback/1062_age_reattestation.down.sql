-- Rollback of 1062: the 1057 bodies of legal_status_for_user and the 6-argument accept, then the column goes.
-- Ships as a new forward migration if ever needed, never pasted (see README).
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
           (SELECT s.age_requirement FROM public.legal_gate_settings s) AS age_requirement,
           (SELECT c.category FROM public.account_age_categories c WHERE c.user_id = target_user_id) AS age_category,
           (SELECT count(*) FROM active) = 2 AS published,
           public.legal_user_has_current_acceptance(target_user_id) AS accepted,
           -- Under 'bands_v2' the prompt asks until the Quebec answer is recorded, whatever the switch. Under any
           -- other requirement it asks exactly as in 1055.
           EXISTS (SELECT 1
                   FROM public.legal_acceptances a
                   JOIN public.legal_documents t ON t.kind = 'terms' AND t.active AND t.version = a.terms_version
                   JOIN public.legal_documents p ON p.kind = 'privacy_notice' AND p.active AND p.version = a.privacy_notice_version
                   CROSS JOIN public.legal_gate_settings s
                   WHERE a.user_id = target_user_id
                     AND CASE WHEN s.age_requirement = 'bands_v2' THEN a.age_attestation = 'bands_v2'
                              ELSE NOT s.enforced OR a.age_attestation IS NOT DISTINCT FROM s.age_requirement END) AS answered
  )
  SELECT jsonb_build_object(
    'enforced', f.enforced,
    'acceptance_required', f.published AND NOT f.answered,
    'blocked', f.enforced AND f.published AND NOT f.accepted,
    'age_requirement', f.age_requirement,
    'age_category', f.age_category,
    'documents', CASE WHEN f.published
                      THEN (SELECT jsonb_object_agg(a.kind, a.doc) FROM active a) END,
    'accepted', (SELECT jsonb_build_object('terms_version', x.terms_version,
                                           'privacy_notice_version', x.privacy_notice_version,
                                           'accepted_at', x.accepted_at,
                                           'acceptance_method', x.acceptance_method,
                                           'age_attestation', x.age_attestation,
                                           'age_band', x.age_band,
                                           'residence', x.residence)
                 FROM public.legal_acceptances x
                 JOIN public.legal_documents t ON t.kind = 'terms' AND t.active AND t.version = x.terms_version
                 JOIN public.legal_documents p ON p.kind = 'privacy_notice' AND p.active AND p.version = x.privacy_notice_version
                 WHERE x.user_id = target_user_id))
  FROM facts f
$$;

CREATE OR REPLACE FUNCTION public.accept_legal_documents(p_method text, p_terms_version text, p_privacy_notice_version text,
                                                         p_age_attestation text, p_age_band text, p_lives_in_quebec boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  caller uuid := nullif(auth.user_id(), '')::uuid;
  terms public.legal_documents%ROWTYPE;
  notice public.legal_documents%ROWTYPE;
  required text := (SELECT s.age_requirement FROM public.legal_gate_settings s);
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'LEGAL_NOT_AUTHENTICATED' USING ERRCODE = '42501';
  END IF;
  IF p_age_attestation IS DISTINCT FROM required OR required <> 'bands_v2' THEN
    RAISE EXCEPTION 'LEGAL_AGE_ATTESTATION_INVALID' USING ERRCODE = '22023',
      DETAIL = format('required %s', required);
  END IF;
  -- Before the age range: a Quebec resident is refused whatever their age, and nothing is recorded.
  IF p_lives_in_quebec IS NULL THEN
    RAISE EXCEPTION 'LEGAL_REGION_REQUIRED' USING ERRCODE = '22023',
      DETAIL = 'answer whether you live in Quebec';
  END IF;
  IF p_lives_in_quebec THEN
    RAISE EXCEPTION 'LEGAL_REGION_NOT_AVAILABLE' USING ERRCODE = '22023',
      DETAIL = 'MoveMark is not offered to Quebec residents yet';
  END IF;
  IF p_age_band IS NULL OR p_age_band NOT IN ('13_17', '18_plus') THEN
    RAISE EXCEPTION 'LEGAL_AGE_BAND_INVALID' USING ERRCODE = '22023';
  END IF;
  IF p_method IS NULL OR p_method NOT IN ('email', 'apple', 'google') THEN
    RAISE EXCEPTION 'LEGAL_INVALID_METHOD' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO terms FROM public.legal_documents d WHERE d.kind = 'terms' AND d.active FOR SHARE;
  SELECT * INTO notice FROM public.legal_documents d WHERE d.kind = 'privacy_notice' AND d.active FOR SHARE;
  IF terms.id IS NULL OR notice.id IS NULL THEN
    RAISE EXCEPTION 'LEGAL_DOCUMENTS_UNAVAILABLE' USING ERRCODE = '22023';
  END IF;
  IF p_terms_version IS DISTINCT FROM terms.version OR p_privacy_notice_version IS DISTINCT FROM notice.version THEN
    RAISE EXCEPTION 'LEGAL_VERSION_NOT_ACTIVE' USING ERRCODE = '22023',
      DETAIL = format('active terms %s, privacy notice %s', terms.version, notice.version);
  END IF;

  -- The first acceptance keeps its time and method; an older answer set (no Quebec answer) is brought up to date.
  INSERT INTO public.legal_acceptances (user_id, terms_version, privacy_notice_version, acceptance_method, document_hashes,
                                        age_attestation, age_attested_at, age_band, residence)
  VALUES (caller, terms.version, notice.version, p_method,
          jsonb_build_object('terms', terms.content_hash, 'privacy_notice', notice.content_hash),
          p_age_attestation, now(), p_age_band, 'outside_quebec')
  ON CONFLICT (user_id, terms_version, privacy_notice_version) DO UPDATE
    SET age_attestation = EXCLUDED.age_attestation, age_attested_at = EXCLUDED.age_attested_at,
        age_band = EXCLUDED.age_band, residence = EXCLUDED.residence
    WHERE (public.legal_acceptances.age_attestation, public.legal_acceptances.age_band, public.legal_acceptances.residence)
          IS DISTINCT FROM (EXCLUDED.age_attestation, EXCLUDED.age_band, EXCLUDED.residence);

  INSERT INTO public.account_age_categories (user_id, category, declared_at)
  VALUES (caller, CASE p_age_band WHEN '13_17' THEN 'teen' ELSE 'adult' END, now())
  ON CONFLICT (user_id) DO UPDATE SET category = EXCLUDED.category, declared_at = EXCLUDED.declared_at
    WHERE public.account_age_categories.category IS DISTINCT FROM EXCLUDED.category;

  RETURN public.legal_status_for_user(caller);
END;
$$;

REVOKE ALL ON FUNCTION public.accept_legal_documents(text, text, text, text, text, boolean) FROM PUBLIC, anonymous;
GRANT EXECUTE ON FUNCTION public.accept_legal_documents(text, text, text, text, text, boolean) TO authenticated;

ALTER TABLE public.legal_acceptances DROP COLUMN age_reattest_required;
