-- =============================================================================
-- 0940 — Immutable source evidence and verified provenance (new, 2026-10-20)
-- =============================================================================
-- Evidence is stored as three objects: the immutable SOURCE (the file as the device
-- produced it — private, never resized or converted), a working DERIVATIVE JPEG (UI,
-- downloads, PDFs; GPS stripped; `file_path`), and a THUMBNAIL (`thumbnail_path`).
--
-- Provenance can't be asserted by a client. The API issues an upload ticket that
-- records the declared source hash/size/type; Object Storage enforces the signed
-- SHA-256 on the PUT; the API's finalize step re-checks the stored object (size,
-- checksum, type, file signature) and marks the ticket `finalized`. An evidence row
-- that names a source is accepted only against a finalized, unexpired, unconsumed
-- ticket of the same user, property and room/issue, with exactly matching paths; its
-- provenance columns are copied FROM THE TICKET (client values ignored) and the ticket
-- is consumed in the same transaction, so it can certify one row only.
--
-- Ticket lifecycle:  issued → finalized → consumed   (abandoned: terminal; expiry by time)
--
-- Timestamps are two different facts and stay separate:
--   captured_at — from the source's own metadata (declared by the file, not verified)
--   created_at  — when MoveMark received it: forced to now() for Data API inserts,
--                 immutable afterwards.
--
-- All new columns are nullable: legacy rows and the not-yet-migrated Android client
-- (S8) keep working without a source; such rows simply carry no provenance.
-- Trigger functions are SECURITY DEFINER (to read the backend-only ticket table) with
-- a fixed search_path, and are not callable over /rpc (trigger functions can't be, and
-- EXECUTE is revoked regardless).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Ticket state machine and declared source facts
-- -----------------------------------------------------------------------------
ALTER TABLE public.storage_upload_tickets
  ADD COLUMN IF NOT EXISTS state             text NOT NULL DEFAULT 'issued',
  ADD COLUMN IF NOT EXISTS resource_id       uuid,          -- room (evidence) or issue (maintenance)
  ADD COLUMN IF NOT EXISTS source_key        text,
  ADD COLUMN IF NOT EXISTS source_mime_type  text,
  ADD COLUMN IF NOT EXISTS source_byte_size  bigint,
  ADD COLUMN IF NOT EXISTS source_sha256     text,
  ADD COLUMN IF NOT EXISTS source_width      integer,
  ADD COLUMN IF NOT EXISTS source_height     integer,
  ADD COLUMN IF NOT EXISTS capture_source    text,
  ADD COLUMN IF NOT EXISTS thumbnail_present boolean,
  ADD COLUMN IF NOT EXISTS finalized_at      timestamptz,
  ADD COLUMN IF NOT EXISTS consumed_at       timestamptz,
  ADD COLUMN IF NOT EXISTS consumed_by       uuid;

UPDATE public.storage_upload_tickets SET state = 'abandoned' WHERE abandoned_at IS NOT NULL AND state = 'issued';

ALTER TABLE public.storage_upload_tickets
  DROP CONSTRAINT IF EXISTS storage_upload_tickets_state_check,
  ADD CONSTRAINT storage_upload_tickets_state_check CHECK (state IN ('issued', 'finalized', 'consumed', 'abandoned'));
CREATE UNIQUE INDEX IF NOT EXISTS storage_upload_tickets_source_key_uniq
  ON public.storage_upload_tickets (source_key) WHERE source_key IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 2. Provenance columns on evidence_files
-- -----------------------------------------------------------------------------
ALTER TABLE public.evidence_files
  ADD COLUMN IF NOT EXISTS source_path       text,
  ADD COLUMN IF NOT EXISTS source_mime_type  text,
  ADD COLUMN IF NOT EXISTS source_byte_size  bigint,
  ADD COLUMN IF NOT EXISTS source_width      integer,
  ADD COLUMN IF NOT EXISTS source_height     integer,
  ADD COLUMN IF NOT EXISTS source_sha256     text,
  ADD COLUMN IF NOT EXISTS capture_source    text;

ALTER TABLE public.evidence_files
  DROP CONSTRAINT IF EXISTS evidence_files_source_mime_check,
  ADD CONSTRAINT evidence_files_source_mime_check
    CHECK (source_mime_type IS NULL OR source_mime_type IN ('image/jpeg', 'image/heic', 'image/heif', 'image/png')),
  DROP CONSTRAINT IF EXISTS evidence_files_source_size_check,
  ADD CONSTRAINT evidence_files_source_size_check
    CHECK (source_byte_size IS NULL OR (source_byte_size > 0 AND source_byte_size <= 26214400)),
  DROP CONSTRAINT IF EXISTS evidence_files_source_dims_check,
  ADD CONSTRAINT evidence_files_source_dims_check
    CHECK ((source_width IS NULL OR source_width > 0) AND (source_height IS NULL OR source_height > 0)),
  DROP CONSTRAINT IF EXISTS evidence_files_source_sha256_check,
  ADD CONSTRAINT evidence_files_source_sha256_check
    CHECK (source_sha256 IS NULL OR source_sha256 ~ '^[0-9a-f]{64}$'),
  DROP CONSTRAINT IF EXISTS evidence_files_capture_source_check,
  ADD CONSTRAINT evidence_files_capture_source_check
    CHECK (capture_source IS NULL OR capture_source IN ('camera', 'library')),
  -- A source is all-or-nothing: either every provenance fact is present, or none is.
  DROP CONSTRAINT IF EXISTS evidence_files_source_complete_check,
  ADD CONSTRAINT evidence_files_source_complete_check
    CHECK ((source_path IS NULL) = (source_sha256 IS NULL)
           AND (source_path IS NULL) = (source_mime_type IS NULL)
           AND (source_path IS NULL) = (source_byte_size IS NULL)
           AND (source_path IS NULL) = (capture_source IS NULL));

CREATE UNIQUE INDEX IF NOT EXISTS evidence_files_source_path_uniq
  ON public.evidence_files (source_path) WHERE source_path IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3. INSERT: server receipt time, and provenance only from a finalized ticket
-- -----------------------------------------------------------------------------
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

DROP TRIGGER IF EXISTS evidence_files_before_insert ON public.evidence_files;
CREATE TRIGGER evidence_files_before_insert
  BEFORE INSERT ON public.evidence_files
  FOR EACH ROW EXECUTE FUNCTION public.evidence_files_before_insert();

-- -----------------------------------------------------------------------------
-- 4. UPDATE: receipt time and provenance are immutable (for everyone)
-- -----------------------------------------------------------------------------
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

DROP TRIGGER IF EXISTS evidence_files_before_update ON public.evidence_files;
CREATE TRIGGER evidence_files_before_update
  BEFORE UPDATE ON public.evidence_files
  FOR EACH ROW EXECUTE FUNCTION public.evidence_files_before_update();

REVOKE EXECUTE ON FUNCTION public.evidence_files_before_insert() FROM authenticated, anonymous, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.evidence_files_before_update() FROM authenticated, anonymous, PUBLIC;

-- -----------------------------------------------------------------------------
-- 5. The 0910 key-folder rule covers the source too (defence in depth)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS evidence_files_source_in_caller_folder_insert ON public.evidence_files;
CREATE POLICY evidence_files_source_in_caller_folder_insert ON public.evidence_files
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (source_path IS NULL OR (lower(source_path) LIKE lower(auth.user_id()) || '/' || property_id::text || '/%'
                                      AND position('..' IN source_path) = 0));
DROP POLICY IF EXISTS evidence_files_source_in_caller_folder_update ON public.evidence_files;
CREATE POLICY evidence_files_source_in_caller_folder_update ON public.evidence_files
  AS RESTRICTIVE FOR UPDATE TO authenticated
  WITH CHECK (source_path IS NULL OR (lower(source_path) LIKE lower(auth.user_id()) || '/' || property_id::text || '/%'
                                      AND position('..' IN source_path) = 0));
