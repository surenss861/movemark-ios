-- =============================================================================
-- 1050 — Legal gate on the Data API, second wave (2026-11-07)
-- =============================================================================
-- 1040 covered the seven highest-risk tables. A gated caller could still read these, because their policies
-- check user_id alone: maintenance issues and checklists directly, and maintenance issues through both
-- snapshot RPCs, which return them by property id. Same policy as 1040, same switch.
-- inspection_item_tags was already hidden through inspection_items; it is listed so that stops depending on
-- how its parent's policy happens to be written. move_out_checklist_state holds no client grant; covered for
-- the same reason.
--
-- Left open on purpose: profiles, issue_tags, legal_* (docs/legal-gate/rls-coverage.md).
--
-- As in 1040, a dead policy goes: disputes_update_own expands into dispute_evidence_links and back into
-- disputes, which now carries a subquery (42P17). `authenticated` has held no UPDATE on disputes since 0960.
-- Rollback: neon/rollback/1050_legal_gate_rls_wave2.down.sql.
-- =============================================================================

DROP POLICY IF EXISTS disputes_update_own ON public.disputes;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['maintenance_issues', 'inspection_item_tags', 'move_out_checklists',
                           'move_out_checklist_state', 'disputes', 'dispute_evidence_links'] LOOP
    EXECUTE format('CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR ALL TO authenticated '
                   'USING ((SELECT public.legal_gate_passes())) WITH CHECK ((SELECT public.legal_gate_passes()))',
                   t || '_legal_gate', t);
  END LOOP;
END $$;
