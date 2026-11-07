-- =============================================================================
-- 1020 — Delete one rental and everything under it (Delete rental, 2026-10-27)
-- =============================================================================
-- Free accounts get one rental, so a rental created by mistake must not consume that slot for good.
-- `DELETE /api/properties/{id}` removes the rental, every row under it, then its stored objects.
--
-- Why a function: the API runs as movemark_api, which (0970) may delete only evidence_files,
-- property_documents, dispute_evidence_links and storage_upload_tickets; properties, rooms,
-- inspections, inspection_items, inspection_item_tags, maintenance_issues, disputes, exports and the
-- move-out tables are closed to it, and none of the foreign keys cascade. Rather than widen the
-- runtime role's table grants, this mirrors account deletion (delete_user_owned_data, 0290/0340/0980):
-- one SECURITY DEFINER function, EXECUTE granted to movemark_api only, nothing for PUBLIC,
-- authenticated or movemark_worker.
--
-- Contract:
--   * Deletes nothing and returns no rows unless target_property_id belongs to target_user_id.
--   * Deletes, child-first, every row that references the rental directly or through a parent:
--       dispute_evidence_links, exports, inspection_item_tags, evidence_files, inspection_items,
--       inspections, maintenance_issues, property_documents, move_out_checklists,
--       move_out_checklist_state, disputes, rooms, storage_upload_tickets, properties.
--     Rows elsewhere that point at a deleted row (a dispute link of another rental naming this
--     rental's evidence, an item of another inspection on this rental's room) go too, so no FK can
--     block the delete. Shared issue_tags and user-level rows (profile, entitlements, credits) stay.
--   * Returns every stored object key the deleted rows referenced, with what the API needs to pick
--     the bucket: kind ('inspection' | 'maintenance' | 'document' | 'export') and document_type.
--     The caller removes those objects after commit (Object Storage can't join the transaction).
--   * Runs in the caller's transaction: all rows go, or none do.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.delete_property_owned_data(target_user_id uuid, target_property_id uuid)
RETURNS TABLE (kind text, document_type text, object_key text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_rooms        uuid[];
  v_inspections  uuid[];
  v_items        uuid[];
  v_issues       uuid[];
  v_documents    uuid[];
  v_disputes     uuid[];
  v_evidence     uuid[];
BEGIN
  IF target_user_id IS NULL OR target_property_id IS NULL THEN
    RAISE EXCEPTION 'target_user_id and target_property_id are required';
  END IF;

  -- Lock the rental row; a rental that isn't the caller's is indistinguishable from a missing one.
  PERFORM 1 FROM public.properties p
   WHERE p.id = target_property_id AND p.user_id = target_user_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT coalesce(array_agg(r.id), '{}') INTO v_rooms
    FROM public.rooms r WHERE r.property_id = target_property_id;
  SELECT coalesce(array_agg(i.id), '{}') INTO v_inspections
    FROM public.inspections i WHERE i.property_id = target_property_id;
  SELECT coalesce(array_agg(ii.id), '{}') INTO v_items
    FROM public.inspection_items ii
   WHERE ii.inspection_id = ANY (v_inspections) OR ii.room_id = ANY (v_rooms);
  SELECT coalesce(array_agg(m.id), '{}') INTO v_issues
    FROM public.maintenance_issues m WHERE m.property_id = target_property_id;
  SELECT coalesce(array_agg(d.id), '{}') INTO v_documents
    FROM public.property_documents d WHERE d.property_id = target_property_id;
  SELECT coalesce(array_agg(d.id), '{}') INTO v_disputes
    FROM public.disputes d WHERE d.property_id = target_property_id;
  SELECT coalesce(array_agg(e.id), '{}') INTO v_evidence
    FROM public.evidence_files e
   WHERE e.property_id = target_property_id
      OR e.inspection_item_id = ANY (v_items)
      OR e.maintenance_issue_id = ANY (v_issues);

  -- Object keys, collected before their rows go.
  RETURN QUERY
    SELECT CASE WHEN e.maintenance_issue_id IS NOT NULL THEN 'maintenance' ELSE 'inspection' END,
           NULL::text, k.key
      FROM public.evidence_files e
     CROSS JOIN LATERAL unnest(ARRAY[e.file_path, e.thumbnail_path, e.source_path]) AS k(key)
     WHERE e.id = ANY (v_evidence) AND k.key IS NOT NULL AND k.key <> '';
  RETURN QUERY
    SELECT 'document', d.document_type, k.key
      FROM public.property_documents d
     CROSS JOIN LATERAL unnest(ARRAY[d.file_path, d.thumbnail_path]) AS k(key)
     WHERE d.id = ANY (v_documents) AND k.key IS NOT NULL AND k.key <> '';
  RETURN QUERY
    SELECT 'export', NULL::text, x.file_path
      FROM public.exports x
     WHERE (x.property_id = target_property_id OR x.dispute_id = ANY (v_disputes))
       AND x.file_path IS NOT NULL AND x.file_path <> '';

  DELETE FROM public.dispute_evidence_links l
   WHERE l.dispute_id = ANY (v_disputes)
      OR l.evidence_file_id = ANY (v_evidence)
      OR l.maintenance_issue_id = ANY (v_issues)
      OR l.property_document_id = ANY (v_documents);

  DELETE FROM public.exports x
   WHERE x.property_id = target_property_id OR x.dispute_id = ANY (v_disputes);

  DELETE FROM public.inspection_item_tags t WHERE t.inspection_item_id = ANY (v_items);
  DELETE FROM public.evidence_files e WHERE e.id = ANY (v_evidence);
  DELETE FROM public.inspection_items ii WHERE ii.id = ANY (v_items);
  DELETE FROM public.inspections i WHERE i.id = ANY (v_inspections);
  DELETE FROM public.maintenance_issues m WHERE m.id = ANY (v_issues);
  DELETE FROM public.property_documents d WHERE d.id = ANY (v_documents);
  DELETE FROM public.move_out_checklists c WHERE c.property_id = target_property_id;
  DELETE FROM public.move_out_checklist_state s WHERE s.property_id = target_property_id;
  DELETE FROM public.disputes d WHERE d.id = ANY (v_disputes);
  DELETE FROM public.rooms r WHERE r.id = ANY (v_rooms);
  DELETE FROM public.storage_upload_tickets t WHERE t.property_id = target_property_id;
  DELETE FROM public.properties p WHERE p.id = target_property_id AND p.user_id = target_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_property_owned_data(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_property_owned_data(uuid, uuid) TO movemark_api;
