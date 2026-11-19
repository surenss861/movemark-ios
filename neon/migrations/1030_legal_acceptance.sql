-- =============================================================================
-- 1030 — Legal acceptance: documents, acceptances, the gate's helpers (2026-11-07)
-- =============================================================================
-- Adds the records and the functions only. Nothing is enforced by this file, and nothing is seeded:
-- a database with 1030 applied behaves for every client exactly as it did before.
--
--   legal_documents       What the renter is asked to accept. Server-managed (published by a migration
--                         through publish_legal_document), append-only except for the `active` flag.
--   legal_acceptances     One row per user per (terms, privacy notice) pair accepted. Written only by
--                         accept_legal_documents; clients may read their own rows and write nothing.
--   legal_gate_settings   One row: `enforced`, false here. The restrictive policies (1040) and the API
--                         dependency both honour it, so enforcement is decided in one place and can be
--                         turned on after the apps that can complete acceptance are in users' hands
--                         (docs/legal-gate/rollout-plan.md). Never granted to any client or runtime role.
--
-- Client surface (Data API, role `authenticated`):
--   rpc get_legal_status()                     what is active, is acceptance outstanding, is it enforced
--   rpc accept_legal_documents(method, terms_version, privacy_notice_version)
--   rpc has_current_legal_acceptance()         boolean, ignores the switch
--   rpc legal_gate_passes()                    boolean, what the RLS policies evaluate (they need EXECUTE)
--   SELECT legal_documents, own legal_acceptances
-- Runtime surface: legal_gate_open_for_user(uuid), legal_status_for_user(uuid) for movemark_api only. They
-- take an arbitrary user id, so clients get neither.
--
-- Rules the functions keep:
--   * Identity comes from auth.user_id(), never from a parameter. Time, active versions and document hashes
--     are read by the server; the client's only inputs are the method and the versions it displayed, and
--     the versions are refused unless they are the active ones, so a screen showing an old version can't
--     record consent to a newer text the renter never saw.
--   * Repeating an acceptance is a no-op: the first row stands, with its time and method.
--   * No complete active pair (nothing published yet) means nothing can be accepted, so nothing is required
--     and the gate stays open. Otherwise publishing the documents would have to precede every other step
--     or lock everyone out.
--
-- SECURITY DEFINER: the helpers must read acceptances for the policy check and must name auth.user_id(),
-- which `authenticated` may execute but cannot reach by name inside a function body (no USAGE on schema
-- auth; see 1000). search_path is pinned, no dynamic SQL, EXECUTE granted per role. RLS cannot recurse: the
-- legal tables' own policies don't use the gate, and these functions run as the table owner.
--
-- Acceptances go with the account: the foreign key cascades from neon_auth."user", so delete_auth_user
-- removes them in the same statement. See the retention note in docs/legal-gate/rollout-plan.md.
-- =============================================================================

CREATE TABLE public.legal_documents (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind          text NOT NULL CHECK (kind IN ('terms', 'privacy_notice')),
  version       text NOT NULL CHECK (version ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'),
  content_hash  text NOT NULL CHECK (content_hash ~ '^[0-9a-f]{64}$'),  -- SHA-256 of the published text
  url           text CHECK (url IS NULL OR url ~ '^https://'),
  is_final      boolean NOT NULL DEFAULT false,  -- false: a draft, shown as such; never enforce on a draft
  published_at  timestamptz NOT NULL DEFAULT now(),
  active        boolean NOT NULL DEFAULT false,
  UNIQUE (kind, version)
);
CREATE UNIQUE INDEX legal_documents_one_active_per_kind ON public.legal_documents (kind) WHERE active;

CREATE TABLE public.legal_acceptances (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 uuid NOT NULL REFERENCES neon_auth."user" (id) ON DELETE CASCADE,
  terms_version           text NOT NULL,
  privacy_notice_version  text NOT NULL,
  accepted_at             timestamptz NOT NULL DEFAULT now(),
  acceptance_method       text NOT NULL CHECK (acceptance_method IN ('email', 'apple', 'google')),
  document_hashes         jsonb NOT NULL,  -- {"terms": <sha256>, "privacy_notice": <sha256>} as accepted
  UNIQUE (user_id, terms_version, privacy_notice_version)
);

CREATE TABLE public.legal_gate_settings (
  singleton   boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  enforced    boolean NOT NULL DEFAULT false,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.legal_gate_settings (singleton) VALUES (true);

-- A published text never changes: a correction is a new version. Only `active` moves.
CREATE OR REPLACE FUNCTION public.legal_documents_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'legal documents are append-only' USING ERRCODE = '42501';
  END IF;
  IF (NEW.id, NEW.kind, NEW.version, NEW.content_hash, NEW.url, NEW.is_final, NEW.published_at)
     IS DISTINCT FROM (OLD.id, OLD.kind, OLD.version, OLD.content_hash, OLD.url, OLD.is_final, OLD.published_at) THEN
    RAISE EXCEPTION 'legal documents are append-only: publish a new version' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER legal_documents_append_only
  BEFORE UPDATE OR DELETE ON public.legal_documents
  FOR EACH ROW EXECUTE FUNCTION public.legal_documents_append_only();

-- Publishing makes the version active and retires the previous one in the same transaction. Migration role
-- only: it runs in a migration (production) or the dev tool, never at runtime.
CREATE OR REPLACE FUNCTION public.publish_legal_document(p_kind text, p_version text, p_content_hash text,
                                                         p_url text DEFAULT NULL, p_is_final boolean DEFAULT false)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  new_id uuid;
BEGIN
  UPDATE public.legal_documents SET active = false WHERE kind = p_kind AND active;
  INSERT INTO public.legal_documents (kind, version, content_hash, url, is_final, active)
  VALUES (p_kind, p_version, p_content_hash, p_url, p_is_final, true)
  RETURNING id INTO new_id;
  RETURN new_id;
END;
$$;

-- The one definition of "this user has accepted what is active now".
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

-- Whether that user may reach protected data right now: the gate is off, there is nothing to accept yet,
-- or the user has accepted. NULL user: closed when enforced.
CREATE OR REPLACE FUNCTION public.legal_gate_open_for_user(target_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT NOT (SELECT s.enforced FROM public.legal_gate_settings s)
      OR (SELECT count(*) FROM public.legal_documents d WHERE d.active) < 2
      OR public.legal_user_has_current_acceptance(target_user_id)
$$;

CREATE OR REPLACE FUNCTION public.has_current_legal_acceptance()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$ SELECT public.legal_user_has_current_acceptance(nullif(auth.user_id(), '')::uuid) $$;

-- What the 1040 policies evaluate, as (SELECT public.legal_gate_passes()): an uncorrelated subquery becomes
-- an InitPlan, computed once per statement however many rows are read.
CREATE OR REPLACE FUNCTION public.legal_gate_passes()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$ SELECT public.legal_gate_open_for_user(nullif(auth.user_id(), '')::uuid) $$;

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

CREATE OR REPLACE FUNCTION public.get_legal_status()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$ SELECT public.legal_status_for_user(nullif(auth.user_id(), '')::uuid) $$;

-- Errors are stable codes in `message`; DETAIL carries the active versions for a stale screen.
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

-- Tables: read-only for clients, and only these two. Runtime roles reach them only through the functions.
ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legal_acceptances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legal_gate_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.legal_documents, public.legal_acceptances, public.legal_gate_settings
  FROM PUBLIC, anonymous, authenticated, movemark_backend, movemark_api, movemark_worker;
GRANT SELECT ON public.legal_documents, public.legal_acceptances TO authenticated;
CREATE POLICY legal_documents_select ON public.legal_documents FOR SELECT TO authenticated USING (true);
CREATE POLICY legal_acceptances_select_own ON public.legal_acceptances FOR SELECT TO authenticated
  USING (user_id = (SELECT (auth.user_id())::uuid));

-- Functions: nothing by default, then exactly who calls what.
REVOKE ALL ON FUNCTION public.legal_documents_append_only() FROM PUBLIC, anonymous, authenticated;
REVOKE ALL ON FUNCTION public.publish_legal_document(text, text, text, text, boolean) FROM PUBLIC, anonymous, authenticated;
REVOKE ALL ON FUNCTION public.legal_user_has_current_acceptance(uuid) FROM PUBLIC, anonymous, authenticated;
REVOKE ALL ON FUNCTION public.legal_gate_open_for_user(uuid) FROM PUBLIC, anonymous, authenticated;
REVOKE ALL ON FUNCTION public.legal_status_for_user(uuid) FROM PUBLIC, anonymous, authenticated;
REVOKE ALL ON FUNCTION public.has_current_legal_acceptance() FROM PUBLIC, anonymous;
REVOKE ALL ON FUNCTION public.legal_gate_passes() FROM PUBLIC, anonymous;
REVOKE ALL ON FUNCTION public.get_legal_status() FROM PUBLIC, anonymous;
REVOKE ALL ON FUNCTION public.accept_legal_documents(text, text, text) FROM PUBLIC, anonymous;
GRANT EXECUTE ON FUNCTION public.has_current_legal_acceptance() TO authenticated;
GRANT EXECUTE ON FUNCTION public.legal_gate_passes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_legal_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_legal_documents(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.legal_gate_open_for_user(uuid) TO movemark_api;
GRANT EXECUTE ON FUNCTION public.legal_status_for_user(uuid) TO movemark_api;
