-- MoveMark — disposable synthetic dataset for index/query/concurrency benchmarks.
--
--   psql "$BENCH_DSN" -v ON_ERROR_STOP=1 -v scale=1 -f scripts/db/synth_scale.sql
--
-- Run only on a throwaway database built from neon/migrations (a local scratch DB or an isolated Neon
-- benchmark branch that is deleted afterwards) — never on dev or production; the guard below refuses
-- the known dev/production endpoints by database identity.
--
-- Shape at scale=1 (deliberately skewed, like real use):
--   20k users · 25k properties · 250k rooms · 50k inspections · ~1.0M inspection items
--   ~1.5M room evidence rows + 100k maintenance evidence · 100k maintenance issues · 75k documents
--   10k disputes · 50k dispute links · 100k exports incl. a 20k queued backlog · 300k item tags
--   ~200k upload tickets · plus one "years of use" property with 50k evidence rows (worst-case listing)
-- Legacy-style evidence rows (no source provenance) so the provenance trigger accepts them unattended.

\set ON_ERROR_STOP 1
\if :{?scale}
\else
  \set scale 1
\endif

DO $$
BEGIN
  IF current_setting('neon.timeline_id', true) IS NOT NULL
     AND EXISTS (SELECT 1 FROM pg_settings WHERE name = 'neon.endpoint_id'
                 AND setting IN ('ep-steep-wind-b56266ss', 'ep-quiet-salad-b55aeba0')) THEN
    RAISE EXCEPTION 'refusing: this is the production or dev endpoint';
  END IF;
  IF EXISTS (SELECT 1 FROM public.properties LIMIT 1) THEN
    RAISE EXCEPTION 'refusing: target already has data (synthetic data goes into an empty scratch database)';
  END IF;
END $$;

SET synchronous_commit = off;

CREATE TEMP TABLE synth_params AS SELECT (:scale)::numeric AS s;

-- Users (neon_auth columns differ locally vs Neon: insert only the shared required ones).
DO $$
DECLARE n int := (20000 * (SELECT s FROM synth_params))::int;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'neon_auth."user"'::regclass AND attname = 'emailVerified') THEN
    EXECUTE format($q$INSERT INTO neon_auth."user" (id, name, email, "emailVerified")
      SELECT ('00000000-0000-4000-8000-' || lpad(to_hex(g), 12, '0'))::uuid, 'Synth ' || g, 'synth' || g || '@bench.test', true
      FROM generate_series(1, %s) g$q$, n);
  ELSE
    EXECUTE format($q$INSERT INTO neon_auth."user" (id, name, email)
      SELECT ('00000000-0000-4000-8000-' || lpad(to_hex(g), 12, '0'))::uuid, 'Synth ' || g, 'synth' || g || '@bench.test'
      FROM generate_series(1, %s) g$q$, n);
  END IF;
END $$;

CREATE TEMP TABLE synth_users AS
SELECT id, row_number() OVER (ORDER BY id) AS n FROM neon_auth."user" WHERE email LIKE 'synth%@bench.test';

INSERT INTO public.profiles (id, email, full_name, onboarding_completed_at)
SELECT id, 'synth' || n || '@bench.test', 'Synth ' || n, now() - random() * interval '700 days' FROM synth_users;

-- Properties: 1.25 per user on average (every 4th user has two).
INSERT INTO public.properties (user_id, title, address_line_1, city, province_state, postal_code, country, deposit_amount, move_in_date, created_at)
SELECT u.id, 'Rental ' || u.n || '-' || k, u.n || ' Synthetic St', 'Toronto', 'ON', 'M5V 1A1', 'CA', 1500, current_date - (random() * 900)::int,
       now() - random() * interval '900 days'
FROM synth_users u CROSS JOIN LATERAL generate_series(1, CASE WHEN u.n % 4 = 0 THEN 2 ELSE 1 END) k;

-- Rooms: 10 per property.
INSERT INTO public.rooms (property_id, name, sort_order, created_at)
SELECT p.id, (ARRAY['Kitchen','Living Room','Primary Bedroom','Bedroom 2','Bathroom','Bathroom 2','Hallway','Laundry','Storage','Balcony/Patio'])[r], r - 1, p.created_at
FROM public.properties p CROSS JOIN generate_series(1, 10) r;

-- Inspections: move-in and move-out per property (unique per property/user/type).
INSERT INTO public.inspections (property_id, user_id, inspection_type, status, created_at)
SELECT p.id, p.user_id, t, CASE WHEN t = 'move_in' THEN 'completed' ELSE 'in_progress' END, p.created_at
FROM public.properties p CROSS JOIN unnest(ARRAY['move_in','move_out']) t;

-- Inspection items: ~2 per room per inspection (≈1.0M).
INSERT INTO public.inspection_items (inspection_id, room_id, notes, condition_rating, created_at)
SELECT i.id, r.id, 'Synthetic entry ' || k, 1 + (random() * 4)::int, i.created_at + k * interval '1 minute'
FROM public.inspections i
JOIN public.rooms r ON r.property_id = i.property_id
CROSS JOIN generate_series(1, 2) k;

-- Room evidence: 1.5 per item on average.
INSERT INTO public.evidence_files (property_id, inspection_item_id, file_path, thumbnail_path, file_type, captured_at, created_at)
SELECT i.property_id, it.id, 'synth/' || it.id || '/' || k || '.jpg', 'synth/' || it.id || '/' || k || '_thumb.jpg', 'image',
       it.created_at, it.created_at + k * interval '1 second'
FROM public.inspection_items it JOIN public.inspections i ON i.id = it.inspection_id
CROSS JOIN LATERAL generate_series(1, 1 + (abs(hashtext(it.id::text)) % 2)) k;

-- Maintenance issues (4 per property) with one evidence photo each.
INSERT INTO public.maintenance_issues (property_id, user_id, title, category, status, date_discovered, created_at)
SELECT p.id, p.user_id, 'Issue ' || k, 'General', (ARRAY['open','follow_up','resolved'])[1 + k % 3], current_date - k, p.created_at + k * interval '1 day'
FROM public.properties p CROSS JOIN generate_series(1, 4) k;
INSERT INTO public.evidence_files (property_id, maintenance_issue_id, file_path, file_type, captured_at, created_at)
SELECT m.property_id, m.id, 'synth/m/' || m.id || '.jpg', 'image', m.created_at, m.created_at FROM public.maintenance_issues m;

-- Documents: 3 per property.
INSERT INTO public.property_documents (property_id, user_id, document_type, file_path, file_name, uploaded_at)
SELECT p.id, p.user_id, t, 'synth/d/' || p.id || '/' || t || '.pdf', t || '.pdf', p.created_at
FROM public.properties p CROSS JOIN unnest(ARRAY['lease','deposit_receipt','listing_screenshot']) t;

-- Disputes on 40% of properties, 5 evidence links each.
INSERT INTO public.disputes (property_id, user_id, title, dispute_type, status, created_at)
SELECT p.id, p.user_id, 'Deposit dispute', 'deposit_withheld', 'draft', p.created_at + interval '300 days'
FROM public.properties p WHERE abs(hashtext(p.id::text)) % 10 < 4;
INSERT INTO public.dispute_evidence_links (dispute_id, evidence_file_id)
SELECT d.id, e.id FROM public.disputes d
CROSS JOIN LATERAL (SELECT id FROM public.evidence_files ef WHERE ef.property_id = d.property_id LIMIT 5) e;

-- Item tags on ~30% of items.
INSERT INTO public.issue_tags (name) SELECT unnest(ARRAY['Scratch','Stain','Water damage','Chipped paint','Cracked tile','Appliance damage'])
ON CONFLICT (name) DO NOTHING;
INSERT INTO public.inspection_item_tags (inspection_item_id, issue_tag_id)
SELECT it.id, (SELECT id FROM public.issue_tags ORDER BY name OFFSET abs(hashtext(it.id::text)) % 6 LIMIT 1)
FROM public.inspection_items it WHERE abs(hashtext(it.id::text)) % 10 < 3;

-- Exports: 4 completed per property, plus a queued backlog (one active job per property/type allowed).
INSERT INTO public.exports (user_id, property_id, export_type, status, file_path, created_at, completed_at)
SELECT p.user_id, p.id, (ARRAY['move_in_report','move_out_report','dispute_packet','move_in_report'])[k], 'completed',
       'synth/x/' || p.id || '/' || k || '.pdf', p.created_at + k * interval '10 days', p.created_at + k * interval '10 days'
FROM public.properties p CROSS JOIN generate_series(1, 4) k;
INSERT INTO public.exports (user_id, property_id, export_type, status, created_at, requested_at)
SELECT p.user_id, p.id, 'move_in_report', 'queued', now() - random() * interval '1 hour', now()
FROM public.properties p ORDER BY p.id LIMIT (20000 * (SELECT s FROM synth_params))::int;

-- Billing tables.
INSERT INTO public.user_report_credits (user_id, balance) SELECT id, n % 3 FROM synth_users;
INSERT INTO public.user_entitlements (user_id, status, product_id) SELECT id, 'active', 'movemark_pro_monthly' FROM synth_users WHERE n % 5 = 0;

-- Upload tickets: consumed history + a live tail.
INSERT INTO public.storage_upload_tickets (id, user_id, property_id, kind, bucket, object_key, state, created_at, expires_at, consumed_at)
SELECT gen_random_uuid(), p.user_id, p.id, 'evidence', 'inspection-media', 'synth/t/' || p.id || '/' || k || '.jpg',
       CASE WHEN k = 8 THEN 'issued' ELSE 'consumed' END, now() - k * interval '1 hour', now() + interval '1 day' - k * interval '1 hour',
       CASE WHEN k = 8 THEN NULL ELSE now() - k * interval '1 hour' END
FROM public.properties p CROSS JOIN generate_series(1, 8) k;

-- Worst case: one property used for years — 50k evidence rows on one inspection.
DO $$
DECLARE big uuid; insp uuid;
BEGIN
  SELECT id INTO big FROM public.properties ORDER BY id LIMIT 1;
  SELECT id INTO insp FROM public.inspections WHERE property_id = big AND inspection_type = 'move_in';
  INSERT INTO public.inspection_items (inspection_id, room_id, notes, condition_rating, created_at)
  SELECT insp, (SELECT id FROM public.rooms WHERE property_id = big ORDER BY sort_order LIMIT 1), 'Long-term entry ' || g, 4,
         now() - g * interval '30 minutes'
  FROM generate_series(1, 25000) g;
  INSERT INTO public.evidence_files (property_id, inspection_item_id, file_path, file_type, captured_at, created_at)
  SELECT big, it.id, 'synth/big/' || it.id || '/' || k || '.jpg', 'image', it.created_at, it.created_at
  FROM public.inspection_items it CROSS JOIN generate_series(1, 2) k
  WHERE it.inspection_id = insp AND it.notes LIKE 'Long-term entry %';
END $$;

ANALYZE;

SELECT relname AS table, n_live_tup AS rows FROM pg_stat_user_tables WHERE schemaname IN ('public', 'neon_auth')
ORDER BY n_live_tup DESC;
