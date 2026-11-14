-- =============================================================================
-- 1040 — Legal gate on the Data API, first wave (2026-11-07)
-- =============================================================================
-- One RESTRICTIVE policy per table, for the role the apps use. A restrictive policy is AND-ed with the
-- ownership policies already there, so none of them is rewritten: a row must still be the caller's, and
-- the caller must also pass the gate. It applies to SELECT, INSERT, UPDATE and DELETE alike.
--
-- Scope: the seven highest-risk direct paths. docs/legal-gate/rls-coverage.md lists every table and function
-- and what remains. Not touched: profiles, legal_*, issue_tags, and everything the runtime roles do: their
-- own policies are `TO movemark_api` / `TO movemark_worker`, so account deletion, webhooks and the API's own
-- enforcement (the API dependency) are unaffected.
--
-- A gated caller sees: SELECT and the snapshot RPCs return nothing; INSERT fails with 42501; UPDATE and
-- DELETE match no rows.
--
-- Effect while legal_gate_settings.enforced is false (the default): none; legal_gate_passes() is true.
--
-- One existing policy goes: inspections_update_own. Postgres refuses a policy expansion that re-enters a
-- table whose policies contain a subquery, and the gate gives inspections one. UPDATE on inspections would
-- expand update_own -> inspection_items -> inspections and die with 42P17 (HTTP 500). The policy was already
-- dead: 0960 revoked UPDATE on inspections from `authenticated`, so no client can reach it, and without it
-- the attempt ends in 42501 as before. test_legal_gate.py expands every command on every client table.
--
-- Performance: (SELECT public.legal_gate_passes()) is an InitPlan, evaluated once per statement. Measured in
-- docs/legal-gate/rollout-plan.md. Rollback: neon/rollback/1040_legal_gate_rls.down.sql (drops the policies).
-- =============================================================================

DROP POLICY IF EXISTS inspections_update_own ON public.inspections;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['properties', 'rooms', 'inspections', 'inspection_items', 'evidence_files',
                           'property_documents', 'exports'] LOOP
    EXECUTE format('CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR ALL TO authenticated '
                   'USING ((SELECT public.legal_gate_passes())) WITH CHECK ((SELECT public.legal_gate_passes()))',
                   t || '_legal_gate', t);
  END LOOP;
END $$;
