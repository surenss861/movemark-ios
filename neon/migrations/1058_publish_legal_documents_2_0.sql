-- =============================================================================
-- 1058: publish Terms of Service 2.0 and Privacy Policy 2.0 as FINAL documents.
--
-- USER-FACING. From this migration on, get_legal_status returns acceptance_required = true for every account
-- without a bands_v2 acceptance of these versions. RC5 (iOS 1.4, 20261109.1) and Android rc1 show a full-screen
-- agreement step with no skip (Accept, Sign out, Delete account), even while legal_gate_settings.enforced is
-- false. Older iOS builds (20261107.1, 20261108.2) can't accept under bands_v2 and stall at the gate.
-- Enforcement is a separate, later migration.
--
-- The hashes MUST equal the SHA-256 of the text live at the URLs (website `npm run legal:manifest`, with
-- LEGAL_FINAL=true already deployed: A4b before A5). If the text changes before production, edit this file
-- (it is unapplied on production) and re-rehearse on a disposable child of dev, never dev itself.
--
-- Rollback: rollback/1058_publish_legal_documents_2_0.down.sql, shipped as 1059.
-- =============================================================================

SELECT public.publish_legal_document(
  'terms', '2.0',
  '2943de1f2c7829638ffb14e9926416e47774def64a428fce9c05eed277c1c3f7',
  'https://movemark.ca/terms', true);

SELECT public.publish_legal_document(
  'privacy_notice', '2.0',
  '8e202b106948d1fb9c37bde81257fd0b51220f2973c599f5c0b573bc56e05015',
  'https://movemark.ca/privacy', true);
