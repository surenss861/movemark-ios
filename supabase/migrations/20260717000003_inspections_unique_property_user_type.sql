-- Both the iOS and Android clients do a check-then-insert for "one inspection
-- row per (property, user, inspection_type)" (see InspectionRepository on both
-- platforms). Without a DB-level constraint, two near-simultaneous calls (two
-- devices signed into the same account, or a retried request) can both pass
-- the SELECT check before either INSERT lands, creating duplicate inspections
-- rows for the same property/type -- which then makes evidence-hydration
-- double-count/duplicate that phase's rooms.
--
-- This constraint makes the second concurrent insert fail with a 23505
-- unique_violation instead of silently succeeding; the Android client now
-- catches that and re-selects the winning row (see InspectionRepository.kt).

DO $inspections_unique$
BEGIN
  IF to_regclass('public.inspections') IS NULL THEN
    RAISE NOTICE 'movemark: skipped public.inspections (table does not exist)';
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'inspections'
      AND indexname = 'inspections_property_user_type_unique'
  ) THEN
    CREATE UNIQUE INDEX inspections_property_user_type_unique
      ON public.inspections (property_id, user_id, inspection_type);
  END IF;
END
$inspections_unique$;
