-- Rollback of 1057 (Quebec residence). Ships as the next numbered migration, never pasted (see README).
-- Restores the 1055 definitions and the 'bands_v1' requirement. Acceptances keep their rows: a 'bands_v2'
-- acceptance becomes a 'bands_v1' one (the renter did answer the age range; the Quebec "No" is dropped with the
-- column), so they still count after the rollback. Export legal_acceptances.residence first if it must be kept.

DROP FUNCTION public.accept_legal_documents(text, text, text, text, text, boolean);

UPDATE public.legal_acceptances SET age_attestation = 'bands_v1' WHERE age_attestation = 'bands_v2';
UPDATE public.legal_gate_settings SET age_requirement = 'bands_v1', updated_at = now() WHERE age_requirement = 'bands_v2';

ALTER TABLE public.legal_acceptances
  DROP CONSTRAINT legal_acceptances_bands_v2_needs_residence,
  DROP COLUMN residence,
  DROP CONSTRAINT legal_acceptances_band_with_bands,
  ADD CONSTRAINT legal_acceptances_band_with_bands
    CHECK ((age_attestation = 'bands_v1') = (age_band IS NOT NULL) OR (age_attestation IS NULL AND age_band IS NULL)),
  DROP CONSTRAINT legal_acceptances_age_attestation_check,
  ADD CONSTRAINT legal_acceptances_age_attestation_check
    CHECK (age_attestation IS NULL OR age_attestation IN ('bands_v1', 'age_13_qc_14', 'age_18'));

ALTER TABLE public.legal_gate_settings
  DROP CONSTRAINT legal_gate_settings_age_requirement_check,
  ADD CONSTRAINT legal_gate_settings_age_requirement_check
    CHECK (age_requirement IN ('bands_v1', 'age_13_qc_14', 'age_18')),
  ALTER COLUMN age_requirement SET DEFAULT 'bands_v1';

-- The 1055 bodies, verbatim.
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
           public.legal_user_has_current_acceptance(target_user_id) AS accepted
  )
  SELECT jsonb_build_object(
    'enforced', f.enforced,
    'acceptance_required', f.published AND NOT f.accepted,
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
                                           'age_band', x.age_band)
                 FROM public.legal_acceptances x
                 JOIN public.legal_documents t ON t.kind = 'terms' AND t.active AND t.version = x.terms_version
                 JOIN public.legal_documents p ON p.kind = 'privacy_notice' AND p.active AND p.version = x.privacy_notice_version
                 WHERE x.user_id = target_user_id))
  FROM facts f
$$;

-- The shipping build's path. Same body as 1030 plus one refusal while enforced.
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
  IF (SELECT s.enforced FROM public.legal_gate_settings s) THEN
    RAISE EXCEPTION 'LEGAL_AGE_ATTESTATION_REQUIRED' USING ERRCODE = '22023',
      DETAIL = 'update the app: acceptance needs the age confirmation';
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

  INSERT INTO public.legal_acceptances (user_id, terms_version, privacy_notice_version, acceptance_method, document_hashes)
  VALUES (caller, terms.version, notice.version, p_method,
          jsonb_build_object('terms', terms.content_hash, 'privacy_notice', notice.content_hash))
  ON CONFLICT (user_id, terms_version, privacy_notice_version) DO NOTHING;

  RETURN public.legal_status_for_user(caller);
END;
$$;

-- Build 20261108.1 and later. No defaults on purpose: a defaulted fourth parameter would make a 3-key call
-- ambiguous between the two overloads in the Data API.
CREATE OR REPLACE FUNCTION public.accept_legal_documents(p_method text, p_terms_version text, p_privacy_notice_version text,
                                                         p_age_attestation text)
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
  -- 'bands_v1' needs the range, which only the 5-argument function takes.
  IF p_age_attestation IS DISTINCT FROM required OR required = 'bands_v1' THEN
    RAISE EXCEPTION 'LEGAL_AGE_ATTESTATION_INVALID' USING ERRCODE = '22023',
      DETAIL = format('required %s', required);
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

  -- The first acceptance keeps its time and method; a missing or outdated attestation is filled in.
  INSERT INTO public.legal_acceptances (user_id, terms_version, privacy_notice_version, acceptance_method, document_hashes,
                                        age_attestation, age_attested_at)
  VALUES (caller, terms.version, notice.version, p_method,
          jsonb_build_object('terms', terms.content_hash, 'privacy_notice', notice.content_hash),
          p_age_attestation, now())
  ON CONFLICT (user_id, terms_version, privacy_notice_version) DO UPDATE
    SET age_attestation = EXCLUDED.age_attestation, age_attested_at = EXCLUDED.age_attested_at
    WHERE public.legal_acceptances.age_attestation IS DISTINCT FROM EXCLUDED.age_attestation;

  RETURN public.legal_status_for_user(caller);
END;
$$;
