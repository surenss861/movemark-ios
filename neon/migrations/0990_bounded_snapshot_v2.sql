-- =============================================================================
-- 0990 — Bounded property snapshot (v2), paginated history, aggregated vault summary
-- (Production Database Hardening: unbounded reads, 2026-10-22)
-- =============================================================================
-- get_property_snapshot (v1) returns a property's whole history in one response: every entry, every
-- photo row, every tag, document and maintenance issue — about 0.6 s and several MB at 50k photos, on every
-- launch, property switch and save — and the vault ran one such snapshot per rental just to count rooms.
-- Nothing here limits how much evidence a renter may keep; it limits how much is loaded at once:
--
--   get_property_snapshot_v2   all rooms with their true totals per stage (entries, photos, entries with
--                              notes, issue tags, latest capture); the newest entries per room and stage,
--                              each with its true photo count; the first photos of each returned entry; the
--                              newest documents/maintenance with totals and the set of document types.
--   get_room_entries_page      older entries of one room/stage, newest first, keyset cursor
--                              (created_at, id) — deterministic, no OFFSET.
--   get_entry_photos_page      the rest of one entry's photos in capture order, keyset cursor.
--   get_vault_summaries        one row per rental of the caller: rooms, documented rooms, newest evidence.
--
-- All are SECURITY INVOKER: RLS decides what the caller sees, exactly as for direct Data API reads. Page sizes
-- are clamped server-side. v1 stays callable until both apps use v2; a later migration retires it.
-- =============================================================================

-- Indexes for the newest-first / capture-order keysets and the per-property "newest evidence" lookup.
-- They extend 0950's single-column indexes, which they replace.
CREATE INDEX IF NOT EXISTS inspection_items_insp_room_recent_idx
  ON public.inspection_items (inspection_id, room_id, created_at DESC, id DESC);
DROP INDEX IF EXISTS public.idx_inspection_items_insp_room;
CREATE INDEX IF NOT EXISTS evidence_files_item_order_idx
  ON public.evidence_files (inspection_item_id, created_at, id) WHERE inspection_item_id IS NOT NULL;
DROP INDEX IF EXISTS public.evidence_files_item_idx;
CREATE INDEX IF NOT EXISTS evidence_files_property_recent_idx
  ON public.evidence_files (property_id, created_at DESC, id DESC);

-- One entry as the apps read it: the row, its true photo count, its first photos and its tags.
CREATE OR REPLACE FUNCTION public._entry_payload(p_item_ids uuid[], p_photos_per_entry integer)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'photo_counts', COALESCE((
      SELECT jsonb_object_agg(c.inspection_item_id, c.n)
      FROM (SELECT ef.inspection_item_id, count(*) AS n FROM public.evidence_files ef
            WHERE ef.inspection_item_id = ANY(p_item_ids) GROUP BY ef.inspection_item_id) c
    ), '{}'::jsonb),
    'evidence_files', COALESCE((
      SELECT jsonb_agg(to_jsonb(f) - 'rn' ORDER BY f.inspection_item_id, f.created_at, f.id)
      FROM (SELECT ef.*, row_number() OVER (PARTITION BY ef.inspection_item_id ORDER BY ef.created_at, ef.id) AS rn
            FROM public.evidence_files ef WHERE ef.inspection_item_id = ANY(p_item_ids)) f
      WHERE f.rn <= p_photos_per_entry
    ), '[]'::jsonb),
    'item_tags', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('inspection_item_id', iit.inspection_item_id, 'name', it.name)
                       ORDER BY iit.inspection_item_id, it.name)
      FROM public.inspection_item_tags iit JOIN public.issue_tags it ON it.id = iit.issue_tag_id
      WHERE iit.inspection_item_id = ANY(p_item_ids)
    ), '[]'::jsonb)
  )
$$;

CREATE OR REPLACE FUNCTION public.get_property_snapshot_v2(p_property_id uuid,
                                                           p_entries_per_room integer DEFAULT 30,
                                                           p_photos_per_entry integer DEFAULT 12)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  n_entries integer := least(greatest(coalesce(p_entries_per_room, 30), 1), 100);
  n_photos integer := least(greatest(coalesce(p_photos_per_entry, 12), 1), 50);
  recent uuid[];
  room_stats jsonb;
BEGIN
  -- Newest entries per room and stage: one bounded range scan per (inspection, room) on
  -- (inspection_id, room_id, created_at DESC, id DESC), never a pass over the whole history.
  SELECT coalesce(array_agg(x.id), '{}') INTO recent
  FROM public.inspections i
  JOIN public.rooms r ON r.property_id = i.property_id
  CROSS JOIN LATERAL (SELECT ii.id FROM public.inspection_items ii
                      WHERE ii.inspection_id = i.id AND ii.room_id = r.id
                      ORDER BY ii.created_at DESC, ii.id DESC LIMIT n_entries) x
  WHERE i.property_id = p_property_id;

  -- True totals per room and stage, computed once for the whole property.
  WITH items AS (
    SELECT ii.id, ii.room_id, i.inspection_type, ii.notes, ii.created_at
    FROM public.inspection_items ii JOIN public.inspections i ON i.id = ii.inspection_id
    WHERE i.property_id = p_property_id
  ), photos AS (
    SELECT ef.inspection_item_id, count(*) AS n FROM public.evidence_files ef
    WHERE ef.property_id = p_property_id AND ef.inspection_item_id IS NOT NULL GROUP BY ef.inspection_item_id
  ), tags AS (
    SELECT iit.inspection_item_id, count(*) AS n
    FROM public.inspection_item_tags iit JOIN items ON items.id = iit.inspection_item_id GROUP BY iit.inspection_item_id
  ), per_stage AS (
    SELECT items.room_id, items.inspection_type,
           count(*) AS entries,
           sum(coalesce(photos.n, 0)) AS photos,
           count(*) FILTER (WHERE position(E'\n' IN coalesce(items.notes, '')) > 0
                            AND btrim(substr(items.notes, position(E'\n' IN items.notes) + 1)) <> '') AS with_notes,
           sum(coalesce(tags.n, 0)) AS tags,
           max(items.created_at) AS latest_at
    FROM items LEFT JOIN photos ON photos.inspection_item_id = items.id LEFT JOIN tags ON tags.inspection_item_id = items.id
    GROUP BY items.room_id, items.inspection_type
  )
  SELECT coalesce(jsonb_object_agg(x.room_id, x.stats), '{}'::jsonb) INTO room_stats
  FROM (SELECT room_id, jsonb_object_agg(inspection_type, jsonb_build_object(
          'entries', entries, 'photos', photos, 'entries_with_notes', with_notes, 'issue_tags', tags, 'latest_at', latest_at)) AS stats
        FROM per_stage GROUP BY room_id) x;

  RETURN jsonb_build_object(
    'limits', jsonb_build_object('entries_per_room', n_entries, 'photos_per_entry', n_photos),
    'property', (SELECT to_jsonb(p) FROM public.properties p WHERE p.id = p_property_id),
    'rooms', COALESCE((
      SELECT jsonb_agg(to_jsonb(r) || jsonb_build_object('stats', COALESCE(room_stats -> r.id::text, '{}'::jsonb))
                       ORDER BY r.sort_order, r.id)
      FROM public.rooms r WHERE r.property_id = p_property_id
    ), '[]'::jsonb),
    'inspections', COALESCE((
      SELECT jsonb_agg(to_jsonb(i) ORDER BY i.inspection_type) FROM public.inspections i WHERE i.property_id = p_property_id
    ), '[]'::jsonb),
    'inspection_items', COALESCE((
      SELECT jsonb_agg(to_jsonb(ii) ORDER BY ii.room_id, ii.created_at DESC, ii.id DESC)
      FROM public.inspection_items ii WHERE ii.id = ANY(recent)
    ), '[]'::jsonb),
    'entries', public._entry_payload(recent, n_photos),
    'documents', COALESCE((
      SELECT jsonb_agg(to_jsonb(d) ORDER BY d.uploaded_at DESC, d.id DESC)
      FROM (SELECT * FROM public.property_documents pd WHERE pd.property_id = p_property_id
            ORDER BY pd.uploaded_at DESC, pd.id DESC LIMIT 100) d
    ), '[]'::jsonb),
    'document_types', COALESCE((
      SELECT jsonb_agg(DISTINCT pd.document_type) FROM public.property_documents pd WHERE pd.property_id = p_property_id
    ), '[]'::jsonb),
    'document_count', (SELECT count(*) FROM public.property_documents pd WHERE pd.property_id = p_property_id),
    'maintenance_issues', COALESCE((
      SELECT jsonb_agg(to_jsonb(m) ORDER BY m.created_at DESC, m.id DESC)
      FROM (SELECT * FROM public.maintenance_issues mi WHERE mi.property_id = p_property_id
            ORDER BY mi.created_at DESC, mi.id DESC LIMIT 100) m
    ), '[]'::jsonb),
    'maintenance_count', (SELECT count(*) FROM public.maintenance_issues mi WHERE mi.property_id = p_property_id),
    'maintenance_photo_counts', COALESCE((
      SELECT jsonb_object_agg(c.maintenance_issue_id, c.n)
      FROM (SELECT ef.maintenance_issue_id, count(*) AS n FROM public.evidence_files ef
            WHERE ef.property_id = p_property_id AND ef.maintenance_issue_id IS NOT NULL
            GROUP BY ef.maintenance_issue_id) c
    ), '{}'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_room_entries_page(p_room_id uuid, p_inspection_type text,
                                                        p_before_created_at timestamptz DEFAULT NULL,
                                                        p_before_id uuid DEFAULT NULL,
                                                        p_limit integer DEFAULT 30,
                                                        p_photos_per_entry integer DEFAULT 12)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  n integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  page uuid[];
  more boolean;
  insp uuid;
BEGIN
  IF (p_before_created_at IS NULL) <> (p_before_id IS NULL) THEN
    RAISE EXCEPTION 'cursor needs both created_at and id' USING ERRCODE = '22023';
  END IF;
  -- The room's inspection for this stage (unique per property, owner and type), resolved first so the scan is
  -- a plain range on (inspection_id, room_id, created_at DESC, id DESC) that stops after n + 1 rows.
  SELECT i.id INTO insp FROM public.inspections i JOIN public.rooms r ON r.property_id = i.property_id
  WHERE r.id = p_room_id AND i.inspection_type = p_inspection_type;
  SELECT coalesce(array_agg(x.id ORDER BY x.created_at DESC, x.id DESC), '{}') INTO page
  FROM (SELECT ii.id, ii.created_at
        FROM public.inspection_items ii
        WHERE ii.inspection_id = insp AND ii.room_id = p_room_id
          AND (p_before_created_at IS NULL OR (ii.created_at, ii.id) < (p_before_created_at, p_before_id))
        ORDER BY ii.created_at DESC, ii.id DESC
        LIMIT n + 1) x;
  more := cardinality(page) > n;
  IF more THEN page := page[1:n]; END IF;
  RETURN jsonb_build_object(
    'inspection_items', COALESCE((
      SELECT jsonb_agg(to_jsonb(ii) ORDER BY ii.created_at DESC, ii.id DESC) FROM public.inspection_items ii WHERE ii.id = ANY(page)
    ), '[]'::jsonb),
    'entries', public._entry_payload(page, least(greatest(coalesce(p_photos_per_entry, 12), 1), 50)),
    'has_more', more
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_entry_photos_page(p_inspection_item_id uuid,
                                                        p_after_created_at timestamptz DEFAULT NULL,
                                                        p_after_id uuid DEFAULT NULL,
                                                        p_limit integer DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  n integer := least(greatest(coalesce(p_limit, 50), 1), 200);
  rows jsonb;
  got integer;
BEGIN
  IF (p_after_created_at IS NULL) <> (p_after_id IS NULL) THEN
    RAISE EXCEPTION 'cursor needs both created_at and id' USING ERRCODE = '22023';
  END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(f) ORDER BY f.created_at, f.id), '[]'::jsonb), count(*) INTO rows, got
  FROM (SELECT ef.* FROM public.evidence_files ef
        WHERE ef.inspection_item_id = p_inspection_item_id
          AND (p_after_created_at IS NULL OR (ef.created_at, ef.id) > (p_after_created_at, p_after_id))
        ORDER BY ef.created_at, ef.id
        LIMIT n + 1) f;
  IF got > n THEN rows := rows - n; END IF;  -- drop the look-ahead row
  RETURN jsonb_build_object('evidence_files', rows, 'has_more', got > n);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_vault_summaries()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'property_id', p.id,
           'rooms_total', (SELECT count(*) FROM public.rooms r WHERE r.property_id = p.id),
           -- Per room, stop at the first move-in entry that has a photo (rooms are few; entries can be many).
           'rooms_documented', (
             SELECT count(*) FROM public.rooms r
             WHERE r.property_id = p.id
               AND EXISTS (SELECT 1 FROM public.inspection_items ii
                           WHERE ii.room_id = r.id
                             AND ii.inspection_id IN (SELECT i.id FROM public.inspections i
                                                      WHERE i.property_id = p.id AND i.inspection_type = 'move_in')
                             AND EXISTS (SELECT 1 FROM public.evidence_files ef WHERE ef.inspection_item_id = ii.id))),
           'latest_evidence', (
             SELECT jsonb_build_object('id', ef.id, 'file_path', ef.file_path, 'thumbnail_path', ef.thumbnail_path,
                                       'maintenance_issue_id', ef.maintenance_issue_id)
             FROM public.evidence_files ef WHERE ef.property_id = p.id
             ORDER BY ef.created_at DESC, ef.id DESC LIMIT 1)
         ) ORDER BY p.created_at, p.id), '[]'::jsonb)
  FROM public.properties p
  WHERE p.user_id = (SELECT auth.user_id())::uuid
$$;

REVOKE ALL ON FUNCTION public._entry_payload(uuid[], integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_property_snapshot_v2(uuid, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_room_entries_page(uuid, text, timestamptz, uuid, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_entry_photos_page(uuid, timestamptz, uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_vault_summaries() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._entry_payload(uuid[], integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_property_snapshot_v2(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_room_entries_page(uuid, text, timestamptz, uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_entry_photos_page(uuid, timestamptz, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_vault_summaries() TO authenticated;
