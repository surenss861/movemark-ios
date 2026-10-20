-- =============================================================================
-- 0910 — Clients may only record object keys inside their own folder (new, 2026-10-20)
-- =============================================================================
-- Apps insert evidence_files / property_documents rows directly through the Data
-- API, and the API later presigns the stored key. Without this, a client could
-- record ANOTHER user's key in its own row and get it signed. These RESTRICTIVE
-- policies (AND-ed with the existing ownership policies) require every recorded
-- key to start with "<caller id>/<property id>/", which is exactly the format the
-- API's upload endpoint generates. Applies to the Data API role only; the trusted
-- backend connects as owner and is not subject to RLS.
-- The check is inlined (no helper function), so nothing new is callable via /rpc.
-- The API also re-checks the key folder when signing (defence in depth).
-- =============================================================================

DROP POLICY IF EXISTS evidence_files_keys_in_caller_folder_insert ON public.evidence_files;
CREATE POLICY evidence_files_keys_in_caller_folder_insert ON public.evidence_files
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK ((file_path IS NULL OR (lower(file_path) LIKE lower(auth.user_id()) || '/' || property_id::text || '/%' AND position('..' IN file_path) = 0))
              AND (thumbnail_path IS NULL OR (lower(thumbnail_path) LIKE lower(auth.user_id()) || '/' || property_id::text || '/%' AND position('..' IN thumbnail_path) = 0)));

DROP POLICY IF EXISTS evidence_files_keys_in_caller_folder_update ON public.evidence_files;
CREATE POLICY evidence_files_keys_in_caller_folder_update ON public.evidence_files
  AS RESTRICTIVE FOR UPDATE TO authenticated
  WITH CHECK ((file_path IS NULL OR (lower(file_path) LIKE lower(auth.user_id()) || '/' || property_id::text || '/%' AND position('..' IN file_path) = 0))
              AND (thumbnail_path IS NULL OR (lower(thumbnail_path) LIKE lower(auth.user_id()) || '/' || property_id::text || '/%' AND position('..' IN thumbnail_path) = 0)));

DROP POLICY IF EXISTS property_documents_keys_in_caller_folder_insert ON public.property_documents;
CREATE POLICY property_documents_keys_in_caller_folder_insert ON public.property_documents
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK ((file_path IS NULL OR (lower(file_path) LIKE lower(auth.user_id()) || '/' || property_id::text || '/%' AND position('..' IN file_path) = 0))
              AND (thumbnail_path IS NULL OR (lower(thumbnail_path) LIKE lower(auth.user_id()) || '/' || property_id::text || '/%' AND position('..' IN thumbnail_path) = 0)));

DROP POLICY IF EXISTS property_documents_keys_in_caller_folder_update ON public.property_documents;
CREATE POLICY property_documents_keys_in_caller_folder_update ON public.property_documents
  AS RESTRICTIVE FOR UPDATE TO authenticated
  WITH CHECK ((file_path IS NULL OR (lower(file_path) LIKE lower(auth.user_id()) || '/' || property_id::text || '/%' AND position('..' IN file_path) = 0))
              AND (thumbnail_path IS NULL OR (lower(thumbnail_path) LIKE lower(auth.user_id()) || '/' || property_id::text || '/%' AND position('..' IN thumbnail_path) = 0)));

-- An earlier draft used a helper function; remove it where it was applied.
DROP FUNCTION IF EXISTS public.mm_key_in_caller_folder(text, uuid);
