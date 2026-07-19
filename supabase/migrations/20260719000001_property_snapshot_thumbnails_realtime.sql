-- Three independent pieces bundled because they all land together for the same
-- scaling pass; each is safe to apply even if the others are skipped.

-- ------------------------------------------------------------
-- 1. get_property_snapshot RPC
-- ------------------------------------------------------------
-- Property hydration on both clients currently does 3 sequential waves of
-- parallel REST calls (5 + 2 + 4 = ~11 network round trips) to assemble one
-- property: rooms, inspections, inspection_items, evidence_files, tags,
-- documents, maintenance_issues. Each wave depends on the previous one's IDs.
--
-- This collapses that to a single round trip. SECURITY INVOKER (the default)
-- means it runs as the calling user, so every subquery below still goes
-- through the same per-table RLS policies as the direct .select() calls it
-- replaces -- this changes round trips, not the security model. A caller who
-- isn't the property's owner gets an empty snapshot (properties row is null,
-- every child collection is empty), matching today's behavior of empty
-- results rather than an explicit error.
CREATE OR REPLACE FUNCTION public.get_property_snapshot(p_property_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'property', (
      SELECT to_jsonb(p) FROM public.properties p WHERE p.id = p_property_id
    ),
    'rooms', COALESCE((
      SELECT jsonb_agg(to_jsonb(r) ORDER BY r.sort_order)
      FROM public.rooms r
      WHERE r.property_id = p_property_id
    ), '[]'::jsonb),
    'inspections', COALESCE((
      SELECT jsonb_agg(to_jsonb(i))
      FROM public.inspections i
      WHERE i.property_id = p_property_id
    ), '[]'::jsonb),
    'inspection_items', COALESCE((
      SELECT jsonb_agg(to_jsonb(ii))
      FROM public.inspection_items ii
      JOIN public.inspections insp ON insp.id = ii.inspection_id
      WHERE insp.property_id = p_property_id
    ), '[]'::jsonb),
    'evidence_files', COALESCE((
      SELECT jsonb_agg(to_jsonb(ef))
      FROM public.evidence_files ef
      WHERE ef.property_id = p_property_id
    ), '[]'::jsonb),
    'item_tags', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'inspection_item_id', iit.inspection_item_id,
        'name', it.name
      ))
      FROM public.inspection_item_tags iit
      JOIN public.issue_tags it ON it.id = iit.issue_tag_id
      JOIN public.inspection_items ii ON ii.id = iit.inspection_item_id
      JOIN public.inspections insp ON insp.id = ii.inspection_id
      WHERE insp.property_id = p_property_id
    ), '[]'::jsonb),
    'documents', COALESCE((
      SELECT jsonb_agg(to_jsonb(pd))
      FROM public.property_documents pd
      WHERE pd.property_id = p_property_id
    ), '[]'::jsonb),
    'maintenance_issues', COALESCE((
      SELECT jsonb_agg(to_jsonb(mi))
      FROM public.maintenance_issues mi
      WHERE mi.property_id = p_property_id
    ), '[]'::jsonb)
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_property_snapshot(uuid) TO authenticated;

-- ------------------------------------------------------------
-- 2. Thumbnail columns
-- ------------------------------------------------------------
-- Clients will upload a small (~320px) JPEG alongside the full-size capture
-- and store its storage path here; grid/list views load this instead of the
-- full-size image. Nullable + no backfill: existing rows just fall back to
-- the full-size path client-side until re-captured.
DO $evidence_files_thumb$
BEGIN
  IF to_regclass('public.evidence_files') IS NULL THEN
    RAISE NOTICE 'movemark: skipped public.evidence_files (table does not exist)';
    RETURN;
  END IF;

  ALTER TABLE public.evidence_files ADD COLUMN IF NOT EXISTS thumbnail_path text;
END
$evidence_files_thumb$;

DO $property_documents_thumb$
BEGIN
  IF to_regclass('public.property_documents') IS NULL THEN
    RAISE NOTICE 'movemark: skipped public.property_documents (table does not exist)';
    RETURN;
  END IF;

  ALTER TABLE public.property_documents ADD COLUMN IF NOT EXISTS thumbnail_path text;
END
$property_documents_thumb$;

-- ------------------------------------------------------------
-- 3. Realtime on exports (replaces client poll loop)
-- ------------------------------------------------------------
-- exports already has RLS enabled with "exports_select_own" (user_id =
-- auth.uid()), so Realtime's postgres_changes broadcast is scoped per-user
-- the same way direct reads are -- adding the table to the publication does
-- not widen who can see which rows.
DO $exports_realtime$
BEGIN
  IF to_regclass('public.exports') IS NULL THEN
    RAISE NOTICE 'movemark: skipped public.exports (table does not exist)';
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'exports'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.exports;
  END IF;
END
$exports_realtime$;
