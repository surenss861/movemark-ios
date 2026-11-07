-- =============================================================================
-- 0980 — Privileged functions per process; validated reaper parameters (P0 review, 2026-10-22)
-- =============================================================================
-- Until now both runtime roles reached every SECURITY DEFINER function through the shared
-- movemark_backend group, so a stolen worker credential could delete accounts or grant credits. Each
-- function is now executable only by the process whose code calls it (from the inventory; the API suite
-- runs as movemark_api and the worker suites as movemark_worker):
--   movemark_api     consume_report_credit, grant_report_credit (RevenueCat webhook),
--                    delete_user_owned_data, delete_auth_user (account deletion)
--   movemark_worker  claim_next_export_job, reap_stuck_export_jobs
-- movemark_backend is left with nothing and the runtime roles leave it.
--
-- Audit of every SECURITY DEFINER function (owner = migration role, search_path pinned to pg_catalog,
-- public, pg_temp, EXECUTE granted explicitly, no PUBLIC): none uses dynamic SQL; all parameters are typed.
-- reap_stuck_export_jobs is the one whose parameters change behaviour materially (a zero window would
-- requeue every running job), so it now refuses out-of-range values.
-- =============================================================================

REVOKE EXECUTE ON FUNCTION public.claim_next_export_job()                      FROM movemark_backend;
REVOKE EXECUTE ON FUNCTION public.reap_stuck_export_jobs(interval, integer)    FROM movemark_backend;
REVOKE EXECUTE ON FUNCTION public.grant_report_credit(uuid, text, text)        FROM movemark_backend;
REVOKE EXECUTE ON FUNCTION public.consume_report_credit(uuid, text)            FROM movemark_backend;
REVOKE EXECUTE ON FUNCTION public.delete_user_owned_data(uuid)                 FROM movemark_backend;
REVOKE EXECUTE ON FUNCTION public.delete_auth_user(uuid)                       FROM movemark_backend;

GRANT EXECUTE ON FUNCTION public.consume_report_credit(uuid, text)     TO movemark_api;
GRANT EXECUTE ON FUNCTION public.grant_report_credit(uuid, text, text) TO movemark_api;
GRANT EXECUTE ON FUNCTION public.delete_user_owned_data(uuid)          TO movemark_api;
GRANT EXECUTE ON FUNCTION public.delete_auth_user(uuid)                TO movemark_api;
GRANT EXECUTE ON FUNCTION public.claim_next_export_job()                    TO movemark_worker;
GRANT EXECUTE ON FUNCTION public.reap_stuck_export_jobs(interval, integer) TO movemark_worker;

REVOKE movemark_backend FROM movemark_api, movemark_worker;

CREATE OR REPLACE FUNCTION public.reap_stuck_export_jobs(stale_after interval DEFAULT '00:05:00'::interval,
                                                         max_attempts integer DEFAULT 3)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  requeued integer := 0;
  failed integer := 0;
BEGIN
  -- Live jobs renew their lease every minute (worker heartbeat); anything shorter than that window would
  -- requeue running jobs.
  IF stale_after IS NULL OR stale_after < interval '2 minutes' OR stale_after > interval '1 day' THEN
    RAISE EXCEPTION 'stale_after must be between 2 minutes and 1 day' USING ERRCODE = '22023';
  END IF;
  IF max_attempts IS NULL OR max_attempts < 1 OR max_attempts > 10 THEN
    RAISE EXCEPTION 'max_attempts must be between 1 and 10' USING ERRCODE = '22023';
  END IF;

  UPDATE public.exports
  SET
    status = 'queued',
    locked_at = NULL,
    updated_at = now(),
    error_message = 'Requeued after worker timeout'
  WHERE status = 'processing'
    AND locked_at IS NOT NULL
    AND locked_at < now() - stale_after
    AND attempts < max_attempts;
  GET DIAGNOSTICS requeued = ROW_COUNT;

  UPDATE public.exports
  SET
    status = 'failed',
    updated_at = now(),
    error_message = 'Export failed after maximum retry attempts'
  WHERE status = 'processing'
    AND locked_at IS NOT NULL
    AND locked_at < now() - stale_after
    AND attempts >= max_attempts;
  GET DIAGNOSTICS failed = ROW_COUNT;

  RETURN requeued + failed;
END;
$$;
