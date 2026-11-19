-- Undoes 1030. DESTROYS every recorded acceptance: for a rollback before any user has accepted, or on a
-- disposable branch. Roll back 1040 first. Same rule as 1040's: forward migration, through the runner.
DROP FUNCTION IF EXISTS public.accept_legal_documents(text, text, text);
DROP FUNCTION IF EXISTS public.get_legal_status();
DROP FUNCTION IF EXISTS public.legal_status_for_user(uuid);
DROP FUNCTION IF EXISTS public.legal_gate_passes();
DROP FUNCTION IF EXISTS public.has_current_legal_acceptance();
DROP FUNCTION IF EXISTS public.legal_gate_open_for_user(uuid);
DROP FUNCTION IF EXISTS public.legal_user_has_current_acceptance(uuid);
DROP FUNCTION IF EXISTS public.publish_legal_document(text, text, text, text, boolean);
DROP TABLE IF EXISTS public.legal_acceptances;
DROP TABLE IF EXISTS public.legal_gate_settings;
DROP TABLE IF EXISTS public.legal_documents;
DROP FUNCTION IF EXISTS public.legal_documents_append_only();
