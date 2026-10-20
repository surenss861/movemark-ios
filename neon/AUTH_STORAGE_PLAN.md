---
related-code:
  - "[[MIGRATION_LEDGER]]"
  - "[[RECONSTRUCTION]]"
domain: data
type: spec
status: wip
author: suren
tags: [movemark, neon, auth, storage, recovery]
---

# Neon Auth and Object Storage integration plan (Option A)

Status: **plan only.** Nothing here has been built. All work targets the Neon `dev` branch; Railway production, Neon `production` and the shipped app configs are untouched until cutover.

## Facts this plan rests on (verified 2026-10-20)

- **Data API with Neon Auth enforces RLS end to end** (`data_api_e2e.py`, 47/47).
- **Neon Auth (Better Auth) on `dev`:**
  - email + password on; verification not required; `allow_localhost` on.
  - OAuth providers: **google, github, vercel only. No Apple.**
- **Each branch has its own Auth and Data API endpoints** (`dev` = `ep-quiet-salad…`, `production` = `ep-steep-wind…`).
- **Object Storage:**
  - S3 API: SigV4, path-style addressing, presigned URLs.
  - Private buckets need a credential for every operation.
  - Credentials are branch-scoped: valid for that branch and its descendants, so a `dev` credential can't reach `production`.

## 1. Auth

### API (S3 in the ledger)

- Verify tokens against the branch's JWKS (`…/neondb/auth/.well-known/jwks.json`), checking signature, `exp` and issuer. Only `sub` is used, exactly as `require_auth` does today.
- Drop the HS256-secret and `auth.get_user` fallbacks.
- **Account deletion:**
  1. `delete_user_owned_data` (unchanged);
  2. object deletion under the user's prefix;
  3. delete the Neon Auth user (admin API, or delete from `neon_auth` as table owner);
  4. bump the Redis generation.

  The order stays retry-safe.

### Native clients (S7 iOS, S8 Android)

- **No Better Auth SDK exists for Swift or Kotlin**, so both apps call Better Auth's HTTP endpoints:
  - `POST /sign-up/email`
  - `POST /sign-in/email`
  - `GET /token` → short-lived JWT
  - `POST /sign-out`
  - password reset
- **Sessions:** the session token is kept in the Keychain (iOS) and EncryptedSharedPreferences (Android). The JWT is refreshed from `/token` before expiry.
- **Data API:**
  - iOS: keep `supabase-swift`'s PostgREST client, pointed at the Data API URL, with the JWT supplied through the client's custom access-token hook.
  - Android: `supabase-kt` with its base URL set to `…/neondb`, so its `/rest/v1` lands on the Data API, plus the same access-token hook.

  Repository code stays as it is.
- **The FastAPI client** sends the same JWT as `Authorization: Bearer`, as today.

### Decision needed: social sign-in on iOS

| Option | Effect |
|---|---|
| **A. Email only at relaunch (recommended)** | No third-party login, so guideline 4.8 does not require Apple. Fastest; same on both platforms. Add social later |
| B. Google + Apple | Google via Neon Auth. Apple needs a separate path: verify Apple's identity token in FastAPI and mint a session. Neon Auth can't do that today, so this is custom auth code and the riskiest piece |
| C. Google only | Not allowed on iOS without Apple (4.8) |

### Before production

- Turn `allow_localhost` off.
- Register trusted redirect origins (`movemark://auth-callback`).
- Set email provider and template branding.
- Decide whether verification is required at sign-up.

## 2. Object Storage

### Buckets

Keep the seven bucket names, so stored `file_path` values and paths keep their meaning:

- `inspection-media`
- `maintenance-media`
- `leases`
- `deposit-receipts`
- `listing-screenshots`
- `documents`
- `exports`

All private. The existing `uploads` bucket is unused.

### API endpoints (S4/S5)

Ownership rule (replaces the Supabase storage policy): the first path segment must equal the caller's `sub`, compared case-insensitively, because Swift writes uppercase UUIDs.

| Endpoint | Behaviour | Replaces |
|---|---|---|
| `POST /api/storage/upload-url` `{bucket, path, contentType}` | Checks bucket allow-list, ownership and content type (`image/jpeg`, `application/pdf`). Returns a presigned `PUT`, valid 10 min | Client `storage.upload` (evidence, thumbnails, maintenance, documents) |
| `POST /api/storage/download-urls` `{bucket, paths[]}` | Ownership check per path; batch presigned `GET`s. Evidence 24h, documents 1h, as today | Client `createSignedURL` |
| `DELETE /api/storage/objects` `{bucket, paths[]}` | Ownership check, then delete | iOS direct deletes |
| `GET /api/exports/{id}/download` | Unchanged contract; S3 presigned GET, 900s, Redis 840s | Supabase signed URL |

- **Worker:** `GetObject` for evidence (same 48-photo / 8-per-room limits, concurrency 8). `PutObject` `{user_id}/{export_id}.pdf` to `exports`.
- **`/api/ready`:** `HeadBucket` on `exports`.
- **Account deletion:** `ListObjectsV2` under both id casings in all seven buckets, then batch delete.
- **Credentials:** the branch S3 credential lives only in Railway (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINT_URL_S3`, `AWS_REGION`). Never in the apps.

**Upload flow change in the apps:** one extra round trip per photo (ask for a URL, then `PUT`). Thumbnails ride on the same request (two paths in one call). The existing per-photo retry and orphan-cleanup logic stays.

## 3. Order of work on `dev`

1. **S1/S2:** API and worker database adapter (psycopg pool, owner role). The existing API suite plus SQL query tests.
2. **S3:** JWKS verification, with tests using real `dev` tokens (the e2e script's sign-up path).
3. **S4/S5:** storage module and the three endpoints. Ownership tests: A cannot get upload, download or delete URLs for B's paths, uppercase paths still work, and buckets outside the allow-list are refused.
4. **Run the whole API locally against `dev`:** create rental → upload photo → snapshot → export → PDF download → delete account. Two users throughout.
5. **S6:** RevenueCat restore and credit rebuild.
6. **S7/S8:** apps against `dev`.
7. **S9:** full two-account QA on devices.

Production cutover is a separate approval: Neon `production` migrations, Railway env, app releases.
