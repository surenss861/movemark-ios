-- =============================================================================
-- 1060 — Deletion tombstones: what a restore must delete again (2026-11-07)
-- =============================================================================
-- A restore brings back whatever was deleted after the backup was taken, including sign-in identities.
-- This table is the capture point for the record that stops that. It can't be the record on its own,
-- because it is restored along with everything else: scripts/dr/deletion_log.py copies it to an append-only
-- log outside this database, and a restore replays that log before the service may start.
-- See docs/backup-retention-design.md.
--
--   deletion_tombstones   One row per deleted account or rental. Holds a salted SHA-256 of the opaque id, the
--                         kind, and the day. No email, no name, no raw id. It is still a pseudonymous
--                         identifier: anyone who already holds the id can test for a match, which is how
--                         replay works. Nobody can go from a row back to a person without that id.
--
-- Capture is in the database so that nothing has to remember to do it, and it commits or rolls back with
-- the deletion itself:
--   delete_user_owned_data   first step of account deletion. Recording here, not at the end, covers a deletion
--                            that fails partway: rows gone, identity not yet. A restore finishes the job.
--   delete_auth_user         last step, also called on its own by QA and support tooling.
--   AFTER DELETE on properties   covers delete_property_owned_data and every other path.
-- The bodies below are 0340's and 0960's with one added statement each; the signatures, owners and grants
-- are unchanged, so the API needs no change.
--
-- Not covered: deleting one photo or one document. Those rows and files can return after a restore until
-- the next retention cycle removes the backups holding them. docs/backup-retention-design.md says so, and
-- so must the Privacy Policy.
--
-- Retention: 120 days, longer than any backup can live (at most 90), so a tombstone always outlasts every
-- backup that could hold its subject. record_deletion removes expired rows, so a row can sit past 120
-- days until the next deletion happens. No runtime role gets a DELETE grant for this.
--
-- Access: RLS on with no policies and nothing granted. Only the SECURITY DEFINER functions here write to
-- it. movemark_backup reads it through pg_read_all_data (1010), which is what the export uses.
-- =============================================================================

CREATE TABLE public.deletion_tombstones (
  kind          text NOT NULL CHECK (kind IN ('account', 'property')),
  subject_hash  text NOT NULL CHECK (subject_hash ~ '^[0-9a-f]{64}$'),
  deleted_on    date NOT NULL DEFAULT ((now() AT TIME ZONE 'utc')::date),
  PRIMARY KEY (kind, subject_hash)
);
CREATE INDEX deletion_tombstones_deleted_on ON public.deletion_tombstones (deleted_on);
ALTER TABLE public.deletion_tombstones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.deletion_tombstones FROM PUBLIC, anonymous, authenticated, movemark_backend, movemark_api, movemark_worker;

-- The hash must stay byte-for-byte equal to subject_hash() in scripts/dr/deletion_log.py.
CREATE OR REPLACE FUNCTION public.record_deletion(target_kind text, target_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF target_id IS NULL THEN
    RAISE EXCEPTION 'target_id is required';
  END IF;
  INSERT INTO public.deletion_tombstones (kind, subject_hash)
  VALUES (target_kind, encode(sha256(convert_to('movemark-deletion-v1:' || lower(target_id::text), 'UTF8')), 'hex'))
  ON CONFLICT (kind, subject_hash) DO NOTHING;
  DELETE FROM public.deletion_tombstones
  WHERE deleted_on < ((now() AT TIME ZONE 'utc')::date - 120);
END;
$$;
REVOKE ALL ON FUNCTION public.record_deletion(text, uuid) FROM PUBLIC, anonymous, authenticated, movemark_backend, movemark_api, movemark_worker;

CREATE OR REPLACE FUNCTION public.record_property_deletion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  PERFORM public.record_deletion('property', OLD.id);
  RETURN OLD;
END;
$$;
REVOKE ALL ON FUNCTION public.record_property_deletion() FROM PUBLIC, anonymous, authenticated, movemark_backend, movemark_api, movemark_worker;

CREATE TRIGGER properties_record_deletion
  AFTER DELETE ON public.properties
  FOR EACH ROW EXECUTE FUNCTION public.record_property_deletion();

CREATE OR REPLACE FUNCTION public.delete_user_owned_data(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'target_user_id is required';
  END IF;

  PERFORM public.record_deletion('account', target_user_id);

  DELETE FROM public.report_credit_events
  WHERE user_id = target_user_id;

  DELETE FROM public.user_report_credits
  WHERE user_id = target_user_id;

  DELETE FROM public.user_entitlements
  WHERE user_id = target_user_id;

  DELETE FROM public.dispute_evidence_links
  WHERE dispute_id IN (
    SELECT id FROM public.disputes WHERE user_id = target_user_id
  );

  DELETE FROM public.exports
  WHERE user_id = target_user_id;

  DELETE FROM public.inspection_item_tags
  WHERE inspection_item_id IN (
    SELECT ii.id
    FROM public.inspection_items ii
    INNER JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE i.user_id = target_user_id
  );

  DELETE FROM public.evidence_files
  WHERE property_id IN (
    SELECT id FROM public.properties WHERE user_id = target_user_id
  );

  DELETE FROM public.inspection_items
  WHERE inspection_id IN (
    SELECT id FROM public.inspections WHERE user_id = target_user_id
  );

  DELETE FROM public.inspections
  WHERE user_id = target_user_id;

  DELETE FROM public.maintenance_issues
  WHERE user_id = target_user_id;

  DELETE FROM public.property_documents
  WHERE user_id = target_user_id;

  DELETE FROM public.move_out_checklists
  WHERE user_id = target_user_id;

  DELETE FROM public.move_out_checklist_state
  WHERE user_id = target_user_id;

  DELETE FROM public.disputes
  WHERE user_id = target_user_id;

  DELETE FROM public.rooms
  WHERE property_id IN (
    SELECT id FROM public.properties WHERE user_id = target_user_id
  );

  DELETE FROM public.properties
  WHERE user_id = target_user_id;

  DELETE FROM public.profiles
  WHERE id = target_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_auth_user(target_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT public.record_deletion('account', target_user_id);
  DELETE FROM neon_auth."user" WHERE id = target_user_id;
$$;
