-- =============================================================================
-- 1057 — Legal gate: Quebec residence answer, Quebec not served yet (2026-11-09)
-- =============================================================================
-- Owner decision (2026-11-09): Quebec is left out of the initial Consumer launch until French Terms, Privacy and
-- purchase text exist. TEMPORARY: when French versions ship, a later migration adds a requirement that accepts
-- Quebec residents (for example 'bands_v3'), and this refusal goes with it.
--
-- Every renter answers "Do you live in Quebec?" (yes or no) on the agreement screen, whatever their age. Nothing
-- else about location is asked or derived: no GPS, no IP geolocation, no province, no postal code.
--
--   legal_gate_settings.age_requirement   New code 'bands_v2' (the new default, and this migration moves a
--                                         'bands_v1' setting to it): the age-range question PLUS the Quebec
--                                         question. 'bands_v1' stays a valid value so the switch can be moved
--                                         back without a migration.
--   legal_acceptances.residence           'outside_quebec', the only value it can hold: the renter's answer
--                                         "No". Required with 'bands_v2'. A "Yes" is never stored anywhere.
--
-- Client surface (role `authenticated`):
--   rpc accept_legal_documents(method, terms_version, privacy_notice_version, age_attestation, age_band,
--                              lives_in_quebec)   NEW, the Quebec build. Refuses unless age_attestation is the
--       current requirement and that requirement is 'bands_v2'. lives_in_quebec NULL: LEGAL_REGION_REQUIRED.
--       lives_in_quebec true: LEGAL_REGION_NOT_AVAILABLE, before the age range is looked at, and nothing is
--       written (the exception rolls the call back, so not even a counter can be kept here; count refusals
--       client-side or from Data API logs if wanted). false: records the acceptance with residence
--       'outside_quebec', the range and the account category, as the 5-argument call does.
--   The 5-argument call (RC3, 20261108.2) and the 4-argument call (20261108.1) refuse under 'bands_v2'
--       (LEGAL_AGE_ATTESTATION_INVALID); those builds show "Update MoveMark" for an age code they don't know.
--   The 3-argument call (20261107.1) now refuses under 'bands_v2' EVEN WHILE ENFORCEMENT IS OFF
--       (LEGAL_AGE_ATTESTATION_REQUIRED): it never asks about Quebec, so it must not form an agreement.
--   get_legal_status(): under 'bands_v2', `acceptance_required` is true until the account has a 'bands_v2'
--       acceptance of the active documents, enforced or not. So an account that accepted without the Quebec answer
--       (a 3-, 4- or 5-argument acceptance) is asked again at its next agreement prompt. Under any other
--       requirement it behaves as in 1055. `blocked` is unchanged: it follows the enforcement switch.
--       `accepted.residence` is added.
--
-- Enforcement is unchanged in mechanism: legal_user_has_current_acceptance (1055) already counts, once enforced,
-- only an acceptance whose attestation equals the current requirement, and a 'bands_v2' acceptance can't exist
-- without residence = 'outside_quebec' (constraint below). So once enforced, an account without a recorded "No"
-- can't pass the Data API policies or the API dependency. While enforcement is off, nothing is gated for anyone,
-- exactly as before: this migration does not stop a client that never calls accept (1.3) from reading data.
--
-- The answer is self-declared, like the age range. It is not location verification and doesn't guarantee that no
-- Quebec resident uses MoveMark. See docs/compliance (and _scratch/compliance-gaps.md section E).
-- =============================================================================

ALTER TABLE public.legal_gate_settings
  DROP CONSTRAINT legal_gate_settings_age_requirement_check,
  ADD CONSTRAINT legal_gate_settings_age_requirement_check
    CHECK (age_requirement IN ('bands_v2', 'bands_v1', 'age_13_qc_14', 'age_18')),
  ALTER COLUMN age_requirement SET DEFAULT 'bands_v2';

-- Only the launch default moves; any other deliberate setting is left alone.
UPDATE public.legal_gate_settings SET age_requirement = 'bands_v2', updated_at = now() WHERE age_requirement = 'bands_v1';

ALTER TABLE public.legal_acceptances
  DROP CONSTRAINT legal_acceptances_age_attestation_check,
  ADD CONSTRAINT legal_acceptances_age_attestation_check
    CHECK (age_attestation IS NULL OR age_attestation IN ('bands_v2', 'bands_v1', 'age_13_qc_14', 'age_18')),
  DROP CONSTRAINT legal_acceptances_band_with_bands,
  ADD CONSTRAINT legal_acceptances_band_with_bands
    CHECK (coalesce(age_attestation IN ('bands_v1', 'bands_v2'), false) = (age_band IS NOT NULL)),
  ADD COLUMN residence text CHECK (residence IS NULL OR residence = 'outside_quebec'),
  ADD CONSTRAINT legal_acceptances_bands_v2_needs_residence
    CHECK (age_attestation IS DISTINCT FROM 'bands_v2' OR residence IS NOT DISTINCT FROM 'outside_quebec');

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

-- Build 20261107.1's path. As in 1055, plus: under 'bands_v2' it refuses whether or not enforcement is on.
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
  IF (SELECT s.enforced OR s.age_requirement = 'bands_v2' FROM public.legal_gate_settings s) THEN
    RAISE EXCEPTION 'LEGAL_AGE_ATTESTATION_REQUIRED' USING ERRCODE = '22023',
      DETAIL = 'update the app: acceptance needs the age and Quebec answers';
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

-- Build 20261108.1's path. As in 1055; the range codes ('bands_v1', 'bands_v2') are never accepted here.
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
  IF p_age_attestation IS DISTINCT FROM required OR required IN ('bands_v1', 'bands_v2') THEN
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

-- The Quebec build: the age range plus the Quebec answer. No defaults (see 1055): a defaulted sixth parameter
-- would make a 5-key call ambiguous in the Data API.
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
