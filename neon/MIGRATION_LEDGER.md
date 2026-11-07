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
| `auth.uid()` in RLS policies | Data API path | `(auth.user_id())::uuid` | S0 | ✅ local · ✅ Neon Data API e2e 47/47 |
| `auth.users` FKs (entitlements, credits) | API | `neon_auth."user"` (Neon Auth enabled on production) | S0 | ✅ local |
| `service_role` grants on privileged functions | API, worker | `movemark_backend` role; Railway connects as table owner; `0900` revokes Neon's default client EXECUTE | S0 | ✅ local · ✅ Neon dev |
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
| API JWT check: HS256 secret → project JWKS → `auth.get_user` | API | Branch JWKS only: EdDSA signature, `iss`/`aud` pinned, `exp`, UUID `sub`, banned rejected; fallbacks removed | S3 | ✅ local · ✅ Neon dev |
| `auth.admin.delete_user` | API account deletion | `DELETE FROM neon_auth."user"` (cascades sessions/accounts) after rows and storage | S3 | ✅ local · ✅ Neon dev |
| `auth.admin.create_user` / `delete_user` | staging verifier scripts | Neon Auth email sign-up over HTTP; teardown via `delete_account_for_user` (`scripts/_neon_fixture.py`) | S9 | ✅ Neon dev (all 3 scripts GO) |

## 4. Storage

| Supabase dependency | Used by | Neon replacement | Step | Status |
|---|---|---|---|---|
| Buckets: inspection-media, maintenance-media, leases, deposit-receipts, listing-screenshots, documents, exports | all | Seven private Neon buckets, same names; API allow-list (`app/object_store.BUCKETS`) | S4 | ✅ Neon dev |
| Storage RLS: first path segment = `auth.uid()`, case-insensitive | clients | API: DB ownership check, server-built or row-stored key, key re-checked against caller's folder (case-insensitive). DB: `0910` restrictive policies stop a client recording a key outside `{caller}/{property}/` | S5 | ✅ local · ✅ Neon dev |
| Client direct upload (evidence, thumbnails, maintenance, documents) | iOS, Android | `POST /api/storage/uploads` → presigned `PUT` (10 min) with signed Content-Type + Content-Length | S5 | ✅ API · ⏳ apps |
| Client signed download URLs (evidence 24h, documents 1h, exports 1h) | iOS, Android | `POST /api/storage/downloads` by row id → presigned `GET`, **1h for evidence and documents** (evidence shortened from 24h) | S5 | ✅ API · ⏳ apps |
| (new) Object uploaded but row insert failed | iOS, Android | Upload ticket (`0920`) + `POST /api/storage/uploads/{id}/abandon`; deletes only unreferenced objects | S5 | ✅ local · ✅ Neon dev |
| Client direct deletes (evidence and documents) | iOS | `DELETE /api/storage/evidence` and `/documents` by row id; objects then rows, server-side | S5 | ✅ API · ⏳ apps |
| API export download (signed 900s, cached 840s in Redis) | API | S3 presigned GET, `EXPORT_URL_TTL_SECONDS`=900, cache 840s (test-enforced below the signature) | S4 | ✅ Neon dev |
| Worker evidence download (≤48 photos, concurrency 8) | worker | S3 GetObject via `app/object_store.py` | S4 | ✅ Neon dev |
| Worker PDF upload `{user_id}/{export_id}.pdf` | worker | S3 PutObject, same key | S4 | ✅ Neon dev |
| Account deletion: recursive remove under `{user_id}` in 7 buckets | API | S3 list + batch delete under lower/upper/as-is casings; every bucket attempted, failures raised so a retry finishes | S4 | ✅ Neon dev |
| `/api/ready` lists the export bucket | API | S3 HeadBucket | S4 | ✅ Neon dev |
| Path convention differences (Android `move_in`, iOS `move-in`; Swift uppercase ids) | clients | New keys: lowercase ids, `move-in`/`move-out`; legacy keys still readable and deletable | — | ✅ |

## 5. API and worker plumbing

| Supabase dependency | Neon replacement | Step | Status |
|---|---|---|---|
| `supabase-py` service-role client (`app/supabase_client.py`) | Pooled Postgres (`app/db.py`, psycopg pool) as table owner; json_agg serialization keeps responses identical | S1 | ✅ local · ✅ Neon dev |
| Manual `.eq("user_id", …)` ownership filters | Same filters in SQL (still required; owner bypasses RLS) | S1 | ✅ |
| Unique-violation 23505 on one-active-job | Same index; psycopg `UniqueViolation` | S1 | ✅ index |
| Worker claim / reap / status writes | Same SQL functions over the pooled connection | S2 | ✅ local · ✅ Neon dev |
| Env: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `SUPABASE_ANON_KEY`, bucket names | `DATABASE_URL` (pooled), `NEON_AUTH_URL`, `AWS_ENDPOINT_URL_S3`/`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_REGION`, bucket names. Supabase settings removed | S1–S4 | ✅ |
| `supabase`, `supabase-auth`, `supabase-functions`, `postgrest`, `storage3`, `realtime` Python packages | Removed (plus their exclusive transitive deps); `boto3` added. Full suite 180/180 in a clean venv without them | S4 | ✅ |
| Query-chain tests against `supabase-py` | Replaced: whole suite runs real SQL on the reconstructed schema (180 passed) + `neon_dev_smoke.py` 25/25 | S1 | ✅ |

## 6. Billing and identity

| Item | Plan | Step | Status |
|---|---|---|---|
| RevenueCat `app_user_id` = old Supabase user id | New Neon Auth ids differ. Reconcile with "Restore purchases", which aliases the new id in RevenueCat and makes the webhook regrant Pro | S6 | 🟡 |
| Report-pack credit balances (Postgres only) | Lost with Supabase. Rebuild from RevenueCat non-subscription purchase history, keyed by event id, so `grant_report_credit` stays idempotent | S6 | 🟡 |
| `user_entitlements` (Pro cache) | Rebuilt from RevenueCat webhooks / restore | S6 | 🟡 |

## 7. Lost with the Supabase project (no replacement possible)

User accounts and identities, all rental, room, evidence, maintenance, document and export rows, all stored photos, documents and PDFs, and credit balances. The only recovery path is a Supabase support export. If one arrives, it's imported into Neon and checked against `0001` (the reconstruction then doubles as a schema diff).
