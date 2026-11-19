-- =============================================================================
-- 1056 — Teen upload privacy (2026-11-08)
-- =============================================================================
-- Owner decision (Option B): for accounts whose declared age category is 'teen' (1055), photos and image documents
-- are stored without location (GPS) or other identifying metadata (camera make/model, serial numbers, owner, lens,
-- maker notes, IPTC/XMP location). The app strips them on the device before anything is saved or uploaded. This
-- migration is the server half, so an older or modified client can't store a teen's photo with that metadata:
--
-- Uploads go from the app straight to object storage on presigned URLs, so the database never sees the bytes. The
-- API does, at finalize: for a teen account it downloads every object of the ticket (source, derivative,
-- thumbnail, or the document and its thumbnail) and sets `metadata_checked` only if none carries identifying
-- metadata. Here, a teen account's rows can only point at objects from such a ticket:
--   * evidence_files INSERT (Data API): a sourced row needs `metadata_checked`; a legacy row without a source is
--     refused (its objects were never checked).
--   * property_documents INSERT (Data API): the file must come from a finalized, checked, unexpired 'document'
--     ticket of the same user and property, which is then consumed.
--   * UPDATE of file_path / thumbnail_path on either table: refused for a teen account.
-- Adults: unchanged. Accounts with no declared category (no acceptance through the age-range call yet): unchanged,
-- which is why this protects every account once enforcement requires that call. The trusted backend (no JWT) is
-- not restricted.
-- =============================================================================

ALTER TABLE public.storage_upload_tickets
  ADD COLUMN metadata_checked boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.account_is_teen(target_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$ SELECT EXISTS (SELECT 1 FROM public.account_age_categories c WHERE c.user_id = target_user_id AND c.category = 'teen') $$;

REVOKE ALL ON FUNCTION public.account_is_teen(uuid) FROM PUBLIC, anonymous, authenticated;
GRANT EXECUTE ON FUNCTION public.account_is_teen(uuid) TO movemark_api, movemark_worker;

CREATE OR REPLACE FUNCTION public.evidence_files_before_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  caller uuid := nullif(auth.user_id(), '')::uuid;  -- NULL for the trusted backend (no JWT)
  owner_id uuid;
  t public.storage_upload_tickets%ROWTYPE;
  item_room uuid;
BEGIN
  -- Clients can't choose when MoveMark received something.
  IF caller IS NOT NULL THEN
    NEW.created_at := now();
  END IF;

  SELECT user_id INTO owner_id FROM public.properties WHERE id = NEW.property_id;
  -- 1056: a teen account's photos are accepted only from a ticket whose objects the API checked for metadata.
  IF caller IS NOT NULL AND public.account_is_teen(owner_id) AND NEW.source_path IS NULL THEN
    RAISE EXCEPTION 'TEEN_UPLOAD_PRIVACY: a teen account''s photos need a verified upload' USING ERRCODE = '42501';
  END IF;

  IF NEW.source_path IS NULL THEN
    IF NEW.source_sha256 IS NOT NULL OR NEW.source_mime_type IS NOT NULL OR NEW.source_byte_size IS NOT NULL
       OR NEW.source_width IS NOT NULL OR NEW.source_height IS NOT NULL OR NEW.capture_source IS NOT NULL THEN
      RAISE EXCEPTION 'provenance can only come from a finalized upload ticket' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;  -- legacy / derivative-only evidence: no provenance claimed
  END IF;

  SELECT * INTO t FROM public.storage_upload_tickets WHERE source_key = NEW.source_path FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'no upload ticket for this source' USING ERRCODE = '42501';
  END IF;
  IF t.user_id IS DISTINCT FROM owner_id OR (caller IS NOT NULL AND t.user_id <> caller)
     OR t.property_id IS DISTINCT FROM NEW.property_id THEN
    RAISE EXCEPTION 'upload ticket belongs to another user or property' USING ERRCODE = '42501';
  END IF;
  IF t.state <> 'finalized' THEN
    RAISE EXCEPTION 'upload ticket is %, not finalized', t.state USING ERRCODE = '42501';
  END IF;
  IF caller IS NOT NULL AND public.account_is_teen(owner_id) AND NOT t.metadata_checked THEN
    RAISE EXCEPTION 'TEEN_UPLOAD_PRIVACY: upload not checked for photo metadata' USING ERRCODE = '42501';
  END IF;
  IF t.expires_at <= now() THEN
    RAISE EXCEPTION 'upload ticket expired' USING ERRCODE = '42501';
  END IF;
  IF t.object_key IS DISTINCT FROM NEW.file_path
     OR NEW.thumbnail_path IS DISTINCT FROM (CASE WHEN t.thumbnail_present THEN t.thumbnail_key END) THEN
    RAISE EXCEPTION 'evidence paths do not match the upload ticket' USING ERRCODE = '42501';
  END IF;
  IF t.kind = 'evidence' THEN
    SELECT room_id INTO item_room FROM public.inspection_items WHERE id = NEW.inspection_item_id;
    IF NEW.inspection_item_id IS NULL OR item_room IS DISTINCT FROM t.resource_id THEN
      RAISE EXCEPTION 'upload ticket was issued for another room' USING ERRCODE = '42501';
    END IF;
  ELSIF t.kind = 'maintenance' THEN
    IF NEW.maintenance_issue_id IS DISTINCT FROM t.resource_id THEN
      RAISE EXCEPTION 'upload ticket was issued for another issue' USING ERRCODE = '42501';
    END IF;
  ELSE
    RAISE EXCEPTION 'upload ticket is not for evidence' USING ERRCODE = '42501';
  END IF;

  -- Trusted facts come from the ticket, whatever the client sent.
  NEW.source_mime_type := t.source_mime_type;
  NEW.source_byte_size := t.source_byte_size;
  NEW.source_sha256    := t.source_sha256;
  NEW.source_width     := t.source_width;
  NEW.source_height    := t.source_height;
  NEW.capture_source   := t.capture_source;

  UPDATE public.storage_upload_tickets
     SET state = 'consumed', consumed_at = now(), consumed_by = NEW.id
   WHERE id = t.id;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.evidence_files_before_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.source_path IS DISTINCT FROM OLD.source_path
     OR NEW.source_mime_type IS DISTINCT FROM OLD.source_mime_type
     OR NEW.source_byte_size IS DISTINCT FROM OLD.source_byte_size
     OR NEW.source_width IS DISTINCT FROM OLD.source_width
     OR NEW.source_height IS DISTINCT FROM OLD.source_height
     OR NEW.source_sha256 IS DISTINCT FROM OLD.source_sha256
     OR NEW.capture_source IS DISTINCT FROM OLD.capture_source
     -- the derivative/thumbnail of a sourced row are bound to that source
     OR (OLD.source_path IS NOT NULL AND (NEW.file_path IS DISTINCT FROM OLD.file_path
                                          OR NEW.thumbnail_path IS DISTINCT FROM OLD.thumbnail_path)) THEN
    RAISE EXCEPTION 'evidence receipt time and provenance are immutable' USING ERRCODE = '42501';
  END IF;
  -- 1056: a teen account can't swap a checked photo for an unchecked one.
  IF nullif(auth.user_id(), '') IS NOT NULL
     AND (NEW.file_path IS DISTINCT FROM OLD.file_path OR NEW.thumbnail_path IS DISTINCT FROM OLD.thumbnail_path)
     AND public.account_is_teen((SELECT p.user_id FROM public.properties p WHERE p.id = NEW.property_id)) THEN
    RAISE EXCEPTION 'TEEN_UPLOAD_PRIVACY: a teen account''s photos need a verified upload' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.property_documents_teen_privacy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  caller uuid := nullif(auth.user_id(), '')::uuid;
  owner_id uuid := (SELECT p.user_id FROM public.properties p WHERE p.id = NEW.property_id);
  t public.storage_upload_tickets%ROWTYPE;
BEGIN
  IF caller IS NULL OR NOT public.account_is_teen(owner_id) THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF NEW.file_path IS DISTINCT FROM OLD.file_path OR NEW.thumbnail_path IS DISTINCT FROM OLD.thumbnail_path THEN
      RAISE EXCEPTION 'TEEN_UPLOAD_PRIVACY: a teen account''s documents need a verified upload' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  SELECT * INTO t FROM public.storage_upload_tickets
   WHERE object_key = NEW.file_path AND kind = 'document' AND user_id = caller FOR UPDATE;
  IF NOT FOUND OR t.property_id IS DISTINCT FROM NEW.property_id OR t.state <> 'finalized'
     OR NOT t.metadata_checked OR t.expires_at <= now()
     OR NEW.thumbnail_path IS DISTINCT FROM (CASE WHEN t.thumbnail_present THEN t.thumbnail_key END) THEN
    RAISE EXCEPTION 'TEEN_UPLOAD_PRIVACY: a teen account''s documents need a verified upload' USING ERRCODE = '42501';
  END IF;
  UPDATE public.storage_upload_tickets SET state = 'consumed', consumed_at = now(), consumed_by = NEW.id WHERE id = t.id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER property_documents_teen_privacy
  BEFORE INSERT OR UPDATE ON public.property_documents
  FOR EACH ROW EXECUTE FUNCTION public.property_documents_teen_privacy();

CREATE INDEX storage_upload_tickets_document_object_idx ON public.storage_upload_tickets (object_key) WHERE kind = 'document';

REVOKE EXECUTE ON FUNCTION public.property_documents_teen_privacy() FROM authenticated, anonymous, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.evidence_files_before_insert() FROM authenticated, anonymous, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.evidence_files_before_update() FROM authenticated, anonymous, PUBLIC;
