-- Launch-scale: async export queue columns + Pro entitlements source of truth.

-- ---------------------------------------------------------------------------
-- exports: worker claim / retry / error fields
-- ---------------------------------------------------------------------------
ALTER TABLE public.exports
  ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS locked_at timestamptz,
  ADD COLUMN IF NOT EXISTS error_message text,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS one_active_job_per_property_type
  ON public.exports (property_id, export_type)
  WHERE status IN ('queued', 'processing');

CREATE INDEX IF NOT EXISTS exports_queued_created_at_idx
  ON public.exports (created_at)
  WHERE status = 'queued';

CREATE INDEX IF NOT EXISTS exports_processing_locked_at_idx
  ON public.exports (locked_at)
  WHERE status = 'processing';

-- Atomically claim the next queued export for a worker (SKIP LOCKED).
CREATE OR REPLACE FUNCTION public.claim_next_export_job()
RETURNS SETOF public.exports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE public.exports AS e
  SET
    status = 'processing',
    locked_at = now(),
    attempts = e.attempts + 1,
    updated_at = now(),
    error_message = NULL
  WHERE e.id = (
    SELECT id
    FROM public.exports
    WHERE status = 'queued'
    ORDER BY created_at ASC
    FOR UPDATE SKIP LOCKED
    LIMIT 1
  )
  RETURNING e.*;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_next_export_job() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_next_export_job() TO service_role;

-- Requeue or fail stuck processing jobs (worker idle loop / cron).
CREATE OR REPLACE FUNCTION public.reap_stuck_export_jobs(
  stale_after interval DEFAULT interval '5 minutes',
  max_attempts integer DEFAULT 3
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  requeued integer := 0;
  failed integer := 0;
BEGIN
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

REVOKE ALL ON FUNCTION public.reap_stuck_export_jobs(interval, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reap_stuck_export_jobs(interval, integer) TO service_role;

-- ---------------------------------------------------------------------------
-- user_entitlements: RevenueCat webhook writes here; API reads for Pro gating
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_entitlements (
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  entitlement_id text NOT NULL DEFAULT 'movemark_pro',
  product_id text,
  status text NOT NULL DEFAULT 'inactive'
    CHECK (status IN ('active', 'inactive', 'expired', 'billing_issue', 'cancelled')),
  expires_at timestamptz,
  environment text,
  revenuecat_app_user_id text,
  last_event_id text,
  last_event_type text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, entitlement_id)
);

ALTER TABLE public.user_entitlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own entitlements" ON public.user_entitlements;
CREATE POLICY "Users can read own entitlements"
  ON public.user_entitlements
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- service_role bypasses RLS; no insert/update policies for authenticated.

CREATE INDEX IF NOT EXISTS user_entitlements_active_idx
  ON public.user_entitlements (user_id)
  WHERE status = 'active';

-- ---------------------------------------------------------------------------
-- Account deletion: also wipe entitlements
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_user_owned_data(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'target_user_id is required';
  END IF;

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

REVOKE ALL ON FUNCTION public.delete_user_owned_data(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_owned_data(uuid) TO service_role;
