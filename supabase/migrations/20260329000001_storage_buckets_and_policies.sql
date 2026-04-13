-- MoveMark: Supabase Storage buckets + RLS for the iOS app.
-- Paths use "{auth.uid()}/..." as the first segment (InspectionRepository, MaintenanceRepository,
-- DocumentRepository, ExportRepository). Resolves "Bucket not found" when buckets were never created.
--
-- First path segment must match auth.uid() case-insensitively (Swift UUID paths are often uppercase).

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('inspection-media', 'inspection-media', false),
  ('maintenance-media', 'maintenance-media', false),
  ('exports', 'exports', false),
  ('leases', 'leases', false),
  ('deposit-receipts', 'deposit-receipts', false),
  ('listing-screenshots', 'listing-screenshots', false),
  ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

-- Authenticated users: read/write/delete only under their own user-id prefix (case-insensitive UUID text).
DROP POLICY IF EXISTS movemark_storage_inspection_media ON storage.objects;
CREATE POLICY movemark_storage_inspection_media ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'inspection-media' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text))
  WITH CHECK (bucket_id = 'inspection-media' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text));

DROP POLICY IF EXISTS movemark_storage_maintenance_media ON storage.objects;
CREATE POLICY movemark_storage_maintenance_media ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'maintenance-media' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text))
  WITH CHECK (bucket_id = 'maintenance-media' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text));

DROP POLICY IF EXISTS movemark_storage_exports ON storage.objects;
CREATE POLICY movemark_storage_exports ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'exports' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text))
  WITH CHECK (bucket_id = 'exports' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text));

DROP POLICY IF EXISTS movemark_storage_leases ON storage.objects;
CREATE POLICY movemark_storage_leases ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'leases' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text))
  WITH CHECK (bucket_id = 'leases' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text));

DROP POLICY IF EXISTS movemark_storage_deposit_receipts ON storage.objects;
CREATE POLICY movemark_storage_deposit_receipts ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'deposit-receipts' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text))
  WITH CHECK (bucket_id = 'deposit-receipts' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text));

DROP POLICY IF EXISTS movemark_storage_listing_screenshots ON storage.objects;
CREATE POLICY movemark_storage_listing_screenshots ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'listing-screenshots' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text))
  WITH CHECK (bucket_id = 'listing-screenshots' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text));

DROP POLICY IF EXISTS movemark_storage_documents ON storage.objects;
CREATE POLICY movemark_storage_documents ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'documents' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text))
  WITH CHECK (bucket_id = 'documents' AND lower(split_part(name, '/', 1)) = lower(auth.uid()::text));
