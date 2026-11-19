-- =============================================================================
-- 1055 — Legal gate: age-eligibility attestation (2026-11-08)
-- =============================================================================
-- Owner decisions D1 and Option B (2026-11-08): a mandatory age declaration inside the acceptance screen, no date
-- of birth. Phase 1 eligibility is 13+ (14+ in Quebec). The renter declares an age range, "13 to 17" or "18 or
-- older"; under 13, and 13 in Quebec, are Phase 2 (parental consent) and can't accept. The declaration is
-- self-declared, not verified. The declared range is the account's age category, which drives the teen upload
-- privacy rule in 1056 (photos stripped of location and identifying metadata before storage). Numbered below 1060
-- on purpose: production gets 1030-1056 from a checkout without 1060.
--
--   legal_gate_settings.age_requirement   What the renter must confirm, as a code the apps map to their own
--                                         copy: 'bands_v1' (the age-range question; the default), or the
--                                         single-box statements 'age_13_qc_14' / 'age_18' that build 20261108.1
--                                         understands. Server-only.
--   legal_acceptances.age_attestation     The code the renter confirmed, and when; age_band the range declared
--                                         ('13_17' or '18_plus', required with 'bands_v1'). NULL for an
--                                         acceptance made through the 3-argument function (20261107.1 and older).
--   account_age_categories                One row per account: 'teen' or 'adult', from the latest declaration.
--
-- Client surface (role `authenticated`):
--   rpc accept_legal_documents(method, terms_version, privacy_notice_version, age_attestation, age_band)   NEW,
--       build 20261108.2+. Refuses unless age_attestation equals the current requirement and, for 'bands_v1',
--       age_band is '13_17' or '18_plus' (LEGAL_AGE_BAND_INVALID). Records the band and the account category.
--   rpc accept_legal_documents(method, terms_version, privacy_notice_version, age_attestation)   NEW, build
--       20261108.1. Refuses (LEGAL_AGE_ATTESTATION_INVALID) unless age_attestation equals the current
--       requirement; with 'bands_v1' in force that never holds, so 20261108.1 can't accept (it shows "Update").
--   rpc accept_legal_documents(method, terms_version, privacy_notice_version)   unchanged signature, kept for
--       the shipping build. While enforcement is off it records an acceptance with no attestation, as before.
--       While enforcement is on it refuses (LEGAL_AGE_ATTESTATION_REQUIRED): such a row would not count anyway.
--   get_legal_status() now also returns `age_requirement`, `age_category`, and `accepted.age_attestation`/`age_band`.
--
-- The one definition of "accepted" (legal_user_has_current_acceptance) changes in one way: once
-- legal_gate_settings.enforced is true, an acceptance counts only if its attestation equals the current
-- age_requirement. So the RLS policies (1040/1050, via legal_gate_passes) and the API dependency
-- (legal_gate_open_for_user) treat a missing or outdated attestation as not accepted, from the same switch,
-- and an old client fails closed. While enforcement is off nothing changes for anyone: nobody is gated.
--
-- Detection is by RPC signature, inside the database: the attestation is a parameter of the function the
-- token's user calls; no header or client version is trusted. The attestation is self-declared; that is the
-- whole of the age check; it is not age verification (Neon Auth creates accounts before MoveMark sees them; see
-- docs/compliance/minors-and-age.md).
-- =============================================================================

ALTER TABLE public.legal_gate_settings
  ADD COLUMN age_requirement text NOT NULL DEFAULT 'bands_v1'
    CHECK (age_requirement IN ('bands_v1', 'age_13_qc_14', 'age_18'));

ALTER TABLE public.legal_acceptances
  ADD COLUMN age_attestation text CHECK (age_attestation IS NULL OR age_attestation IN ('bands_v1', 'age_13_qc_14', 'age_18')),
  ADD COLUMN age_attested_at timestamptz,
  ADD COLUMN age_band text CHECK (age_band IS NULL OR age_band IN ('13_17', '18_plus')),
  ADD CONSTRAINT legal_acceptances_age_attested_together
    CHECK ((age_attestation IS NULL) = (age_attested_at IS NULL)),
  ADD CONSTRAINT legal_acceptances_band_with_bands
    CHECK ((age_attestation = 'bands_v1') = (age_band IS NOT NULL) OR (age_attestation IS NULL AND age_band IS NULL));

-- The account's declared age category. Written only by accept_legal_documents (5 arguments); read by the teen
-- upload rule (1056), the status, and the report. Goes with the account.
CREATE TABLE public.account_age_categories (
  user_id      uuid PRIMARY KEY REFERENCES neon_auth."user" (id) ON DELETE CASCADE,
  category     text NOT NULL CHECK (category IN ('teen', 'adult')),
  declared_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.account_age_categories ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_age_categories FROM PUBLIC, anonymous, authenticated, movemark_backend, movemark_api, movemark_worker;

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
    CROSS JOIN public.legal_gate_settings s
    WHERE a.user_id = target_user_id
      AND (NOT s.enforced OR a.age_attestation IS NOT DISTINCT FROM s.age_requirement))
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


-- Build 20261108.2 and later: the age range. No defaults (see above).
CREATE OR REPLACE FUNCTION public.accept_legal_documents(p_method text, p_terms_version text, p_privacy_notice_version text,
                                                         p_age_attestation text, p_age_band text)
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
  IF p_age_attestation IS DISTINCT FROM required OR required <> 'bands_v1' THEN
    RAISE EXCEPTION 'LEGAL_AGE_ATTESTATION_INVALID' USING ERRCODE = '22023',
      DETAIL = format('required %s', required);
  END IF;
  -- Under 13, and 13 in Quebec, are not a range this function takes: Phase 1 has no parental consent.
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

  INSERT INTO public.legal_acceptances (user_id, terms_version, privacy_notice_version, acceptance_method, document_hashes,
                                        age_attestation, age_attested_at, age_band)
  VALUES (caller, terms.version, notice.version, p_method,
          jsonb_build_object('terms', terms.content_hash, 'privacy_notice', notice.content_hash),
          p_age_attestation, now(), p_age_band)
  ON CONFLICT (user_id, terms_version, privacy_notice_version) DO UPDATE
    SET age_attestation = EXCLUDED.age_attestation, age_attested_at = EXCLUDED.age_attested_at, age_band = EXCLUDED.age_band
    WHERE (public.legal_acceptances.age_attestation, public.legal_acceptances.age_band)
          IS DISTINCT FROM (EXCLUDED.age_attestation, EXCLUDED.age_band);

  INSERT INTO public.account_age_categories (user_id, category, declared_at)
  VALUES (caller, CASE p_age_band WHEN '13_17' THEN 'teen' ELSE 'adult' END, now())
  ON CONFLICT (user_id) DO UPDATE SET category = EXCLUDED.category, declared_at = EXCLUDED.declared_at
    WHERE public.account_age_categories.category IS DISTINCT FROM EXCLUDED.category;

  RETURN public.legal_status_for_user(caller);
END;
$$;

REVOKE ALL ON FUNCTION public.accept_legal_documents(text, text, text, text) FROM PUBLIC, anonymous;
REVOKE ALL ON FUNCTION public.accept_legal_documents(text, text, text, text, text) FROM PUBLIC, anonymous;
GRANT EXECUTE ON FUNCTION public.accept_legal_documents(text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_legal_documents(text, text, text, text) TO authenticated;
