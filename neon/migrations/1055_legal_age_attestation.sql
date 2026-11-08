-- =============================================================================
-- 1055 — Legal gate: age-eligibility attestation (2026-11-08)
-- =============================================================================
-- Owner decision D1: a mandatory age-eligibility confirmation inside the acceptance screen, no date of birth.
-- Minimum 13, 14 in Quebec. Numbered below 1060 on purpose: production gets 1030–1055 from a checkout without
-- 1060 (the runner refuses a pending migration numbered below the newest applied one).
--
--   legal_gate_settings.age_requirement   The statement the renter must confirm, as a code the apps map to
--                                         their own copy: 'age_13_qc_14' ("13 or older, 14 or older in
--                                         Quebec") or 'age_18' (the 18+ fallback, owner's call). Server-only.
--   legal_acceptances.age_attestation     The code the renter confirmed, and when. NULL for an acceptance made
--                                         through the 3-argument function (build 20261107.1 and older).
--
-- Client surface (role `authenticated`):
--   rpc accept_legal_documents(method, terms_version, privacy_notice_version, age_attestation)   NEW overload.
--       Refuses (LEGAL_AGE_ATTESTATION_INVALID) unless age_attestation equals the current requirement, so an
--       ineligible renter — who can't tick the box — has no way to record an acceptance through it.
--   rpc accept_legal_documents(method, terms_version, privacy_notice_version)   unchanged signature, kept for
--       the shipping build. While enforcement is off it records an acceptance with no attestation, as before.
--       While enforcement is on it refuses (LEGAL_AGE_ATTESTATION_REQUIRED): such a row would not count anyway.
--   get_legal_status() now also returns `age_requirement`, and `accepted.age_attestation`.
--
-- The one definition of "accepted" (legal_user_has_current_acceptance) changes in one way: once
-- legal_gate_settings.enforced is true, an acceptance counts only if its attestation equals the current
-- age_requirement. So the RLS policies (1040/1050, via legal_gate_passes) and the API dependency
-- (legal_gate_open_for_user) treat a missing or outdated attestation as not accepted, from the same switch,
-- and an old client fails closed. While enforcement is off nothing changes for anyone: nobody is gated.
--
-- Detection is by RPC signature, inside the database: the attestation is a parameter of the function the
-- token's user calls; no header or client version is trusted. The attestation is self-declared; that is the
-- whole of the age check (Neon Auth creates accounts before MoveMark sees them; see
-- docs/compliance/minors-and-age.md).
-- =============================================================================

ALTER TABLE public.legal_gate_settings
  ADD COLUMN age_requirement text NOT NULL DEFAULT 'age_13_qc_14'
    CHECK (age_requirement IN ('age_13_qc_14', 'age_18'));

ALTER TABLE public.legal_acceptances
  ADD COLUMN age_attestation text CHECK (age_attestation IS NULL OR age_attestation IN ('age_13_qc_14', 'age_18')),
  ADD COLUMN age_attested_at timestamptz,
  ADD CONSTRAINT legal_acceptances_age_attested_together
    CHECK ((age_attestation IS NULL) = (age_attested_at IS NULL));

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
           (SELECT count(*) FROM active) = 2 AS published,
           public.legal_user_has_current_acceptance(target_user_id) AS accepted
  )
  SELECT jsonb_build_object(
    'enforced', f.enforced,
    'acceptance_required', f.published AND NOT f.accepted,
    'blocked', f.enforced AND f.published AND NOT f.accepted,
    'age_requirement', f.age_requirement,
    'documents', CASE WHEN f.published
                      THEN (SELECT jsonb_object_agg(a.kind, a.doc) FROM active a) END,
    'accepted', (SELECT jsonb_build_object('terms_version', x.terms_version,
                                           'privacy_notice_version', x.privacy_notice_version,
                                           'accepted_at', x.accepted_at,
                                           'acceptance_method', x.acceptance_method,
                                           'age_attestation', x.age_attestation)
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
  IF p_age_attestation IS DISTINCT FROM required THEN
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

REVOKE ALL ON FUNCTION public.accept_legal_documents(text, text, text, text) FROM PUBLIC, anonymous;
GRANT EXECUTE ON FUNCTION public.accept_legal_documents(text, text, text, text) TO authenticated;
