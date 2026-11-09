-- Rollback of 1058 (publish 2.0). Ships as 1059, never pasted (see README).
-- Documents are append-only; only `active` moves. Retiring 2.0 leaves no active document of either kind, so
-- get_legal_status reports acceptance_required = false again and clients stop showing the agreement step.
-- Acceptances of 2.0 keep their rows (they become history). Republishing later is a new version, never a re-insert.
UPDATE public.legal_documents SET active = false WHERE version = '2.0' AND kind IN ('terms', 'privacy_notice') AND active;
