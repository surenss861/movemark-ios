-- =============================================================================
-- 0920 — Upload tickets, so a failed row insert can be cleaned up (new, 2026-10-20)
-- =============================================================================
-- Object Storage and Postgres can't share a transaction: an app can upload the
-- bytes and then fail to insert the evidence_files / property_documents row.
-- `POST /api/storage/uploads` records here exactly which object(s) it signed, for
-- whom; `POST /api/storage/uploads/{ticket}/abandon` deletes them only if the
-- ticket is the caller's AND no row references either key. The app sends the
-- ticket id, never a bucket or key.
--
-- Backend only: RLS on with no policies, and every client grant revoked, so the
-- Data API can neither read nor write tickets.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.storage_upload_tickets (
  id             uuid PRIMARY KEY,
  user_id        uuid NOT NULL,
  property_id    uuid NOT NULL,
  kind           text NOT NULL CHECK (kind IN ('evidence', 'maintenance', 'document')),
  bucket         text NOT NULL,
  object_key     text NOT NULL,
  thumbnail_key  text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  expires_at     timestamptz NOT NULL,
  abandoned_at   timestamptz
);

CREATE INDEX IF NOT EXISTS storage_upload_tickets_user_idx ON public.storage_upload_tickets (user_id);
-- For a later sweeper of tickets that were never used or abandoned.
CREATE INDEX IF NOT EXISTS storage_upload_tickets_expires_idx ON public.storage_upload_tickets (expires_at)
  WHERE abandoned_at IS NULL;

ALTER TABLE public.storage_upload_tickets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.storage_upload_tickets FROM authenticated, anonymous, PUBLIC;
