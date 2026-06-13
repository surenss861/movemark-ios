-- Security hardening: export status constraint + ownership lookup indexes (idempotent).

DO $exports_status$
BEGIN
  IF to_regclass('public.exports') IS NULL THEN
    RAISE NOTICE 'movemark security: skipped exports status constraint (table missing)';
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'exports_status_allowed'
  ) THEN
    EXECUTE $sql$
      ALTER TABLE public.exports
        ADD CONSTRAINT exports_status_allowed
        CHECK (status IN ('queued', 'processing', 'completed', 'failed'))
    $sql$;
  END IF;

  EXECUTE $sql$
    CREATE INDEX IF NOT EXISTS idx_exports_user_id_id
      ON public.exports (user_id, id)
  $sql$;

  EXECUTE $sql$
    CREATE INDEX IF NOT EXISTS idx_exports_user_property_type_created
      ON public.exports (user_id, property_id, export_type, created_at DESC)
  $sql$;
END
$exports_status$;

DO $properties_owner$
BEGIN
  IF to_regclass('public.properties') IS NULL THEN
    RAISE NOTICE 'movemark security: skipped properties owner index (table missing)';
    RETURN;
  END IF;

  EXECUTE $sql$
    CREATE INDEX IF NOT EXISTS idx_properties_user_id_id
      ON public.properties (user_id, id)
  $sql$;
END
$properties_owner$;
