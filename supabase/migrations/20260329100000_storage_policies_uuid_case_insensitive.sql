-- Repair: storage.objects policies with case-sensitive UUID path match broke iOS uploads
-- ("new row violates row-level security policy") because Swift uses uppercase UUID strings and
-- Postgres `auth.uid()::text` is often lowercase.
--
-- Safe if you already fixed `20260329000001` in place — this DROP/CREATE matches that `lower(...)` shape.
-- Run on any project that applied the older equality without `lower()`.

DROP POLICY IF EXISTS movemark_storage_inspection_media ON storage.objects;
CREATE POLICY movemark_storage_inspection_media ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'inspection-media'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'inspection-media'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  );

DROP POLICY IF EXISTS movemark_storage_maintenance_media ON storage.objects;
CREATE POLICY movemark_storage_maintenance_media ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'maintenance-media'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'maintenance-media'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  );

DROP POLICY IF EXISTS movemark_storage_exports ON storage.objects;
CREATE POLICY movemark_storage_exports ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'exports'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'exports'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  );

DROP POLICY IF EXISTS movemark_storage_leases ON storage.objects;
CREATE POLICY movemark_storage_leases ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'leases'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'leases'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  );

DROP POLICY IF EXISTS movemark_storage_deposit_receipts ON storage.objects;
CREATE POLICY movemark_storage_deposit_receipts ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'deposit-receipts'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'deposit-receipts'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  );

DROP POLICY IF EXISTS movemark_storage_listing_screenshots ON storage.objects;
CREATE POLICY movemark_storage_listing_screenshots ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'listing-screenshots'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'listing-screenshots'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  );

DROP POLICY IF EXISTS movemark_storage_documents ON storage.objects;
CREATE POLICY movemark_storage_documents ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'documents'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  )
  WITH CHECK (
    bucket_id = 'documents'
    AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text)
  );
