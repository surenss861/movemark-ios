-- Rollback of 1056 (teen upload privacy). Ships as the next numbered migration, never pasted. Restores the 0940
-- trigger bodies; teen accounts then upload like adults (the app still strips on the device).
DROP TRIGGER property_documents_teen_privacy ON public.property_documents;
DROP FUNCTION public.property_documents_teen_privacy();
DROP INDEX public.storage_upload_tickets_document_object_idx;

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
  SELECT user_id INTO owner_id FROM public.properties WHERE id = NEW.property_id;
  IF t.user_id IS DISTINCT FROM owner_id OR (caller IS NOT NULL AND t.user_id <> caller)
     OR t.property_id IS DISTINCT FROM NEW.property_id THEN
    RAISE EXCEPTION 'upload ticket belongs to another user or property' USING ERRCODE = '42501';
  END IF;
  IF t.state <> 'finalized' THEN
    RAISE EXCEPTION 'upload ticket is %, not finalized', t.state USING ERRCODE = '42501';
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
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.evidence_files_before_insert() FROM authenticated, anonymous, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.evidence_files_before_update() FROM authenticated, anonymous, PUBLIC;
DROP FUNCTION public.account_is_teen(uuid);
ALTER TABLE public.storage_upload_tickets DROP COLUMN metadata_checked;
