---
related-code:
  - "[[RECONSTRUCTION]]"
  - "[[0001_reconstructed_base_schema.sql]]"
domain: data
type: spec
status: wip
author: suren
tags: [movemark, neon, recovery, ledger]
---

# Supabase → Neon migration ledger

Every Supabase dependency found in the iOS app, the Android app, the FastAPI API and the worker, mapped to its replacement. Nothing here is "done" until its gate passes on the Neon `dev` branch.

**Steps** (the agreed recovery order):

| Step | Work |
|---|---|
| S0 | Database on Neon dev |
| S1 | API database adapter |
| S2 | Worker database adapter |
| S3 | Neon Auth token verification |
| S4 | Object Storage abstraction |
| S5 | Upload / download / delete link endpoints |
| S6 | RevenueCat reconciliation |
| S7 | iOS against dev |
| S8 | Android against dev |
| S9 | Two-account security, export and PDF QA |

**Status:**

| Status | Meaning |
|---|---|
| ✅ | Verified locally |
| ⏳ | Not started |
| 🟡 | Designed, not built |
| ⛔ | Blocked |

## 1. Database

| Supabase dependency | Used by | Neon replacement | Step | Status |
|---|---|---|---|---|
| 15 dashboard-created base tables (no migration) | all | `0001_reconstructed_base_schema.sql` (assumptions A1–A15) | S0 | ✅ local · ⏳ Neon |
| 28 tracked migrations | all | 25 ported + 2 superseded + 1 never-applied, via `port_migrations.py` | S0 | ✅ local · ⏳ Neon |
| `auth.uid()` in RLS policies | Data API path | `(auth.user_id())::uuid` | S0 | ✅ local |
| `auth.users` FKs (entitlements, credits) | API | `neon_auth."user"` (Neon Auth enabled on production) | S0 | ✅ local |
| `service_role` grants on privileged functions | API, worker | `movemark_backend` role; Railway connects as table owner | S0 | ✅ local |
| Supabase default grants to `authenticated` | clients | `0000` grants + Data API's `authenticated` role | S0 | ✅ local |
| `get_property_snapshot` RPC | iOS, Android | Same function, `SECURITY INVOKER`, under RLS | S0 | ✅ local |
| `claim_next_export_job`, `reap_stuck_export_jobs` | worker | Same functions; queue tests pass against ported SQL | S0 | ✅ local |
| `grant_report_credit`, `consume_report_credit` | API (webhook, enqueue) | Same functions | S0 | ✅ local |
| `delete_user_owned_data` | API (account deletion) | Same function | S0 | ✅ local |
| `supabase_realtime` publication on `exports` | iOS, Android | Removed; both apps already poll every 15s | S0 | ✅ (no-op) |
| Issue tag seed (6 tags) | all | Seed migration replays | S0 | ✅ local |

## 2. Client data access (PostgREST, both apps)

| Supabase dependency | Neon replacement | Step | Status |
|---|---|---|---|
| PostgREST base URL + anon key in `Secrets.xcconfig` / `local.properties` | Neon Data API URL; no anon key (requests carry the user's Neon Auth JWT) | S7/S8 | ⏳ |
| `supabase-swift` / `supabase-kt` PostgREST clients for 13 tables + 1 RPC | Keep the PostgREST client code and point it at the Data API (Option A) | S7/S8 | ⏳ |
| `profiles` upsert on sign-in | Unchanged (RLS: `id = auth.user_id()`) | S7/S8 | ⏳ |
| `move_out_checklists` upsert on `property_id,user_id` (iOS) | Unique key reconstructed | S7 | ✅ schema |

## 3. Auth

| Supabase dependency | Used by | Neon replacement | Step | Status |
|---|---|---|---|---|
| Email sign-up / sign-in / password reset | iOS, Android | Neon Auth (Better Auth) email + password | S7/S8 | ⏳ |
| Apple sign-in, Google sign-in | iOS | Neon Auth social providers (OAuth setup in Neon) | S7 | ⏳ needs OAuth config |
| Session persistence and refresh (SDK) | iOS, Android | Better Auth session + JWT for API/Data API calls | S7/S8 | ⏳ |
| `movemark://auth-callback` redirect | iOS | Same scheme registered as a trusted redirect | S7 | ⏳ |
| API JWT check: HS256 secret → project JWKS → `auth.get_user` | API | Verify against `NEON_AUTH_JWKS_URL`; use only `sub` (as today) | S3 | ⏳ |
| `auth.admin.delete_user` | API account deletion | Neon Auth admin delete (or delete from `neon_auth`) after `delete_user_owned_data` | S3 | ⏳ |
| `auth.admin.create_user` / `delete_user` | staging verifier scripts | Neon Auth admin API on dev | S9 | ⏳ |

## 4. Storage

| Supabase dependency | Used by | Neon replacement | Step | Status |
|---|---|---|---|---|
| Buckets: inspection-media, maintenance-media, leases, deposit-receipts, listing-screenshots, documents, exports | all | Private Neon buckets, same names (or one bucket with prefixes; decide in S4) | S4 | 🟡 |
| Storage RLS: first path segment = `auth.uid()`, case-insensitive | clients | API issues links only for paths starting with the caller's id, compared case-insensitively | S5 | 🟡 |
| Client direct upload (evidence, thumbnails, maintenance, documents) | iOS, Android | `POST` upload-link endpoint → client `PUT`s to the presigned URL | S5 | ⏳ |
| Client signed download URLs (evidence 24h, documents 1h, exports 1h) | iOS, Android | Download-link endpoint, same expiries | S5 | ⏳ |
| Client direct deletes (evidence and documents) | iOS | Delete endpoint (verifies ownership, removes object) | S5 | ⏳ |
| API export download (signed 900s, cached 840s in Redis) | API | S3 presigned GET, same TTLs and cache | S4 | ⏳ |
| Worker evidence download (≤48 photos, concurrency 8) | worker | S3 GetObject | S4 | ⏳ |
| Worker PDF upload `{user_id}/{export_id}.pdf` | worker | S3 PutObject, same key | S4 | ⏳ |
| Account deletion: recursive remove under `{user_id}` in 7 buckets | API | S3 list + batch delete under both id casings | S4 | ⏳ |
| `/api/ready` lists the export bucket | API | S3 HeadBucket / ListObjects | S4 | ⏳ |
| Path convention differences (Android `move_in`, iOS `move-in`; Swift uppercase ids) | clients | Keep as stored; the worker reads `file_path` | — | noted |

## 5. API and worker plumbing

| Supabase dependency | Neon replacement | Step | Status |
|---|---|---|---|
| `supabase-py` service-role client (`app/supabase_client.py`) | Pooled Postgres (psycopg) as table owner; same queries as SQL | S1 | ⏳ |
| Manual `.eq("user_id", …)` ownership filters | Same filters in SQL (still required; owner bypasses RLS) | S1 | ⏳ |
| Unique-violation 23505 on one-active-job | Same index; psycopg `UniqueViolation` | S1 | ✅ index |
| Worker claim / reap / status writes | Same RPCs over the pooled connection | S2 | ⏳ |
| Env: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `SUPABASE_ANON_KEY`, bucket names | `DATABASE_URL` (pooled), `NEON_AUTH_JWKS_URL`, S3 endpoint/keys, bucket names. Old names kept, unused, until cutover | S1–S4 | ⏳ |
| Query-chain tests against `supabase-py` | Rewritten as SQL tests on a Neon dev branch / local Postgres 18 | S1 | ⏳ |

## 6. Billing and identity

| Item | Plan | Step | Status |
|---|---|---|---|
| RevenueCat `app_user_id` = old Supabase user id | New Neon Auth ids differ. Reconcile with "Restore purchases", which aliases the new id in RevenueCat and makes the webhook regrant Pro | S6 | 🟡 |
| Report-pack credit balances (Postgres only) | Lost with Supabase. Rebuild from RevenueCat non-subscription purchase history, keyed by event id, so `grant_report_credit` stays idempotent | S6 | 🟡 |
| `user_entitlements` (Pro cache) | Rebuilt from RevenueCat webhooks / restore | S6 | 🟡 |

## 7. Lost with the Supabase project (no replacement possible)

User accounts and identities, all rental, room, evidence, maintenance, document and export rows, all stored photos, documents and PDFs, and credit balances. The only recovery path is a Supabase support export. If one arrives, it's imported into Neon and checked against `0001` (the reconstruction then doubles as a schema diff).
