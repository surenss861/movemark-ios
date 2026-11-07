-- =============================================================================
-- 0001 — RECONSTRUCTED base schema (written 2026-10-20 for the Neon recovery)
-- =============================================================================
-- The 15 core tables below were created by hand in the Supabase dashboard and were
-- never captured as migrations (the six `*_remote_baseline.sql` files are one-line
-- placeholders). The Supabase project was deleted, so there is no schema to dump.
--
-- This file reconstructs each table AS IT EXISTED BEFORE the tracked migrations ran,
-- from evidence in the repositories:
--   * iOS Codable row types (CodingKeys)           movemork/movemork/Data, Core, Models
--   * Android @Serializable row types (@SerialName) movemark-android/.../data
--   * FastAPI + worker queries                      movemark-api-py/app
--   * the API's real-Postgres harness (exports)     movemark-api-py/tests/export_queue/conftest.py
--   * deleted iOS DisputeRepository (git 0f2d0159^) for disputes / dispute_evidence_links
--   * column, CHECK, FK and policy references in the 28 tracked migrations
--
-- Columns that the tracked migrations ADD are deliberately NOT here (they are added
-- when those migrations replay): exports.status/metadata/error_message/requested_at/
-- completed_at/attempts/locked_at/updated_at, disputes.move_out_date/received_itemized/
-- charge_date, properties.lease_start/rent_amount, evidence_files.thumbnail_path,
-- property_documents.thumbnail_path, move_out_checklist_state PK.
--
-- Every inference is marked  [A#]  and listed in movemork/neon/RECONSTRUCTION.md.
-- Foreign keys use the default NO ACTION: every delete path in the apps and in
-- delete_user_owned_data removes children before parents, which is what NO ACTION
-- requires and what a CASCADE schema would not need  [A1].
-- User-ownership columns (user_id, profiles.id) carry no FK to the auth users table:
-- unknown in the original, and account deletion removes rows explicitly first  [A2].
-- =============================================================================

-- gen_random_uuid() is built in (PG13+). No pgcrypto: the Data API exposes functions in
-- `public`, and pgcrypto would publish ~30 crypto functions there.

-- profiles --------------------------------------------------------------------
-- iOS SessionManager (id, email, full_name, onboarding_completed_at); Android ProfileRepository.
-- Clients upsert their own row with id = the signed-in user's id (no trigger exists).
CREATE TABLE public.profiles (
  id                       uuid PRIMARY KEY,                -- = auth user id  [A2]
  email                    text,
  full_name                text,
  onboarding_completed_at  timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()  -- [A3]
);

-- properties ------------------------------------------------------------------
-- Android PropertyRow is non-null for title/address_line_1/city/province_state/
-- postal_code/country, so rows were always populated  [A4]. Dates are yyyy-MM-dd
-- (iOS dbDateFormatter).
CREATE TABLE public.properties (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL,
  title           text NOT NULL,
  address_line_1  text NOT NULL,
  address_line_2  text,
  city            text NOT NULL,
  province_state  text NOT NULL,
  postal_code     text NOT NULL,
  country         text NOT NULL,
  landlord_name   text,
  landlord_email  text,
  landlord_phone  text,
  deposit_amount  numeric(12, 2),                             -- [A5] same type as rent_amount
  move_in_date    date,
  lease_end       date,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- rooms -----------------------------------------------------------------------
CREATE TABLE public.rooms (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id  uuid NOT NULL REFERENCES public.properties (id),
  name         text NOT NULL,
  sort_order   integer NOT NULL DEFAULT 0,                    -- [A6]
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- inspections -----------------------------------------------------------------
-- Clients insert only property_id/user_id/inspection_type, so `status` must have a
-- default; schema_checks constrains it to in_progress|completed  [A7].
CREATE TABLE public.inspections (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id      uuid NOT NULL REFERENCES public.properties (id),
  user_id          uuid NOT NULL,
  inspection_type  text NOT NULL,
  status           text NOT NULL DEFAULT 'in_progress',       -- [A7]
  scheduled_date   date,                                      -- [A8]
  completed_at     timestamptz,
  overall_notes    text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- inspection_items ------------------------------------------------------------
-- notes stores "title\nnotes" (both apps). condition_rating 1..5 by app convention;
-- no CHECK existed in tracked migrations, so none is added  [A9].
CREATE TABLE public.inspection_items (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id     uuid NOT NULL REFERENCES public.inspections (id),
  room_id           uuid NOT NULL REFERENCES public.rooms (id),
  notes             text,
  condition_rating  integer,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- maintenance_issues ----------------------------------------------------------
-- follow_up_date and updated_at are written as full ISO-8601 instants by both apps.
CREATE TABLE public.maintenance_issues (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id        uuid NOT NULL REFERENCES public.properties (id),
  user_id            uuid NOT NULL,
  title              text NOT NULL,
  category           text,
  description        text,
  status             text NOT NULL DEFAULT 'open',            -- Android default "open"
  date_discovered    date,                                    -- [A10]
  date_reported      date,                                    -- [A10]
  report_method      text,
  landlord_response  text,
  follow_up_date     timestamptz,                             -- [A10]
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

-- evidence_files --------------------------------------------------------------
-- Exactly-one-parent and file_type CHECKs come from 20260312000005.
CREATE TABLE public.evidence_files (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id           uuid NOT NULL REFERENCES public.properties (id),
  inspection_item_id    uuid REFERENCES public.inspection_items (id),
  maintenance_issue_id  uuid REFERENCES public.maintenance_issues (id),
  file_path             text NOT NULL,
  file_type             text NOT NULL,
  captured_at           timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- issue_tags / inspection_item_tags ---------------------------------------------
-- Tags are looked up by name (insertItemTags), so name is unique  [A11].
CREATE TABLE public.issue_tags (
  id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name  text NOT NULL UNIQUE
);

CREATE TABLE public.inspection_item_tags (
  inspection_item_id  uuid NOT NULL REFERENCES public.inspection_items (id),
  issue_tag_id        uuid NOT NULL REFERENCES public.issue_tags (id),
  PRIMARY KEY (inspection_item_id, issue_tag_id)              -- [A12]
);

-- property_documents ----------------------------------------------------------
-- metadata is a string map on Android (Map<String,String>).
CREATE TABLE public.property_documents (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id    uuid NOT NULL REFERENCES public.properties (id),
  user_id        uuid NOT NULL,
  document_type  text NOT NULL,
  file_path      text NOT NULL,
  file_name      text NOT NULL,
  uploaded_at    timestamptz NOT NULL DEFAULT now(),
  metadata       jsonb
);

-- move_out_checklists -----------------------------------------------------------
-- iOS upserts with onConflict "property_id,user_id", which needs this unique key.
CREATE TABLE public.move_out_checklists (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id                uuid NOT NULL REFERENCES public.properties (id),
  user_id                    uuid NOT NULL,
  cabinets_clear             boolean NOT NULL DEFAULT false,
  appliances_clean           boolean NOT NULL DEFAULT false,
  keys_returned              boolean NOT NULL DEFAULT false,
  utilities_cancelled        boolean NOT NULL DEFAULT false,
  cleaning_receipt_uploaded  boolean NOT NULL DEFAULT false,
  forwarding_address_noted   boolean NOT NULL DEFAULT false,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),
  UNIQUE (property_id, user_id)
);

-- move_out_checklist_state ------------------------------------------------------
-- No client, API or worker code has ever read or written this table; only the key
-- columns are known (PK added by 20260312000003). Payload columns UNKNOWN  [A13].
CREATE TABLE public.move_out_checklist_state (
  property_id  uuid NOT NULL REFERENCES public.properties (id),
  user_id      uuid NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- disputes / dispute_evidence_links (legacy; still read by vault_summary) --------
-- Columns from the deleted iOS DisputeRepository (git 0f2d0159^).
CREATE TABLE public.disputes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id         uuid NOT NULL REFERENCES public.properties (id),
  user_id             uuid NOT NULL,
  title               text,
  dispute_type        text NOT NULL,
  status              text NOT NULL DEFAULT 'draft',          -- [A14]
  amount_in_question  numeric(12, 2),                         -- [A5]
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.dispute_evidence_links (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),   -- [A15]
  dispute_id            uuid NOT NULL REFERENCES public.disputes (id),
  evidence_file_id      uuid REFERENCES public.evidence_files (id),
  maintenance_issue_id  uuid REFERENCES public.maintenance_issues (id),
  property_document_id  uuid REFERENCES public.property_documents (id),
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- exports -----------------------------------------------------------------------
-- Baseline columns as documented in the API's real-Postgres harness; dispute_id from
-- the deleted DisputeRepository. file_path starts NOT NULL (20260522000001 relaxes it).
CREATE TABLE public.exports (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL,
  property_id  uuid NOT NULL REFERENCES public.properties (id),
  dispute_id   uuid REFERENCES public.disputes (id),
  export_type  text NOT NULL,
  file_path    text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
