-- =============================================================================
-- 1000 — get_vault_summaries without naming the auth schema (2026-10-22)
-- =============================================================================
-- 0990's get_vault_summaries filtered properties by (SELECT auth.user_id()). On Neon the app role may
-- execute auth.user_id() but has no USAGE on schema auth, so a SECURITY INVOKER function body that names it
-- fails at call time ("permission denied for schema auth"); RLS policies are unaffected because their
-- expressions are resolved once, when the policy is created. The filter was redundant anyway: the function
-- runs as the caller, and RLS on properties already returns only the caller's rentals.
-- (The local platform shim now withholds that USAGE too, so the test suites catch this class of mistake.)
-- =============================================================================

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
  FROM public.properties p  -- RLS: the caller's rentals only
$$;
