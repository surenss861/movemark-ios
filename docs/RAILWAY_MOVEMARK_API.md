# MoveMark Railway API (first pass)

## Endpoints

- `GET /` — service identity JSON
- `GET /api/health` — process liveness (uptime)
- `GET /api/ready` — database + export storage readiness (**503** when dependencies fail)
- `DELETE /api/account` — requires `Authorization: Bearer <Supabase access token>`; permanently deletes the authenticated user, owned rows, and storage objects; returns **204**
- `GET /api/exports` — requires `Authorization: Bearer <Supabase access token>`
- `POST /api/exports/move-in` — auth; body `{ "propertyId": "<uuid>", "format": "pdf" }`; **202** `{ status: "queued" }` (worker builds PDF)
- `POST /api/exports/move-out` — same; Pro required (**402** if unpaid)
- `POST /api/exports/dispute-packet` — same; Pro required
- `GET /api/exports/:id/download` — signed URL when export is `completed`
- `POST /api/webhooks/revenuecat` — upserts `user_entitlements`

## Services (same image)

| Service | Start command |
|---------|----------------|
| Web API | `node dist/index.js` (Dockerfile default) |
| Export worker | `node dist/worker.js` |

Deploy a **second Railway service** from the same repo/image with start command `npm run start:worker` (or `node dist/worker.js`).

## Required Railway variables

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `EXPORT_BUCKET_NAME` (use `exports` if using Supabase Storage bucket `exports`)
- `REVENUECAT_WEBHOOK_SECRET` (required in production)
- `APP_ENV=production`
- `CORS_ALLOWED_ORIGINS` — comma-separated browser origins. Omit to deny browser CORS; native iOS does not rely on CORS.
- `SENTRY_DSN` / `SENTRY_RELEASE` — optional
- `SUPABASE_JWT_SECRET` — optional but recommended; enables local JWT verify (no Auth round-trip)
- `REDIS_URL` — optional; shared rate limits across replicas (falls back to in-memory with eviction)

## Export queue contract

1. API validates auth, ownership, proof gates, **Pro entitlement**, rate limits
2. Inserts `exports` row with `status = queued` and returns **202**
3. Worker claims via `claim_next_export_job()` (`FOR UPDATE SKIP LOCKED`)
4. Worker builds PDF, uploads storage, sets `completed` or `failed` (+ `error_message`)
5. Client polls `GET /api/exports` while status is `queued` / `processing`

Partial unique index `one_active_job_per_property_type` blocks double-tap races.

## Pro gating

- RevenueCat webhook writes `public.user_entitlements`
- iOS must call `Purchases.shared.logIn(supabaseUserId)` (already wired in `SubscriptionManager.syncAuth`)
- Move-out + dispute require active Pro; free tier gets **1** completed move-in export

## Local run

```bash
cd movemark-api
npm install
npm run dev          # API
npm run dev:worker   # worker (separate terminal)
```

Apply migration `20260716000001_export_queue_and_entitlements.sql` before deploying worker/API that expects the new columns/RPCs.

## Notes

- Evidence photo downloads in the worker use capped concurrency (default 8).
- Legacy Edge Function `generate-dispute-packet` is deprecated; Railway PDF path is canonical.
