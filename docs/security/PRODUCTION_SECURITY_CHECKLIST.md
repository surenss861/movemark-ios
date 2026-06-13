# MoveMark production security checklist

MoveMark stores renter photos, leases, deposit receipts, and dispute reports. This checklist is the release gate before production traffic.

**Principle:** Never trust IDs from the client. Every `propertyId`, `exportId`, `documentId`, and `mediaId` must resolve to the authenticated user before returning data or signed URLs.

---

## P0 — Must-have

### Row Level Security (Supabase)

| Table | RLS enabled | Policy basis | Migration reference |
|-------|-------------|--------------|---------------------|
| `profiles` | ✅ | `auth.uid() = user_id` | `20260312000007_rls_policies_direct.sql` |
| `properties` | ✅ | `auth.uid() = user_id` | direct |
| `rooms` | ✅ | via `properties.user_id` | `20260312000008_rls_policies_indirect.sql` |
| `inspections` | ✅ | `auth.uid() = user_id` | direct |
| `inspection_items` | ✅ | via `inspections.user_id` | indirect |
| `evidence_files` | ✅ | property ownership | `20260402000003_full_app_rls_hardening.sql` |
| `property_documents` | ✅ | `auth.uid() = user_id` | direct |
| `exports` | ✅ | `auth.uid() = user_id` + insert guards | hardening |
| `maintenance_issues` | ✅ | `auth.uid() = user_id` | direct |
| `disputes` | ✅ | `auth.uid() = user_id` | direct |
| `dispute_evidence_links` | ✅ | via `disputes.user_id` | indirect |
| `subscriptions` / entitlement cache | ⚠️ verify | RevenueCat webhook only | not in repo schema yet |

**Rule:** RLS must stay enabled on every table in exposed schemas (`public`). No data is reachable via the Data API without policies.

**Production gate:** Checklist documentation is not enough — run `docs/SECURITY_QA.md` (two-account isolation) on the **live Supabase project** after migrations are applied. Confirm in SQL editor:

```sql
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles', 'properties', 'rooms', 'inspections',
    'evidence_files', 'property_documents', 'exports'
  );
```

All listed tables must show `rowsecurity = true`, with owner-based policies applied.

### Storage buckets (private)

| Bucket | Public | Path rule | Migration |
|--------|--------|-----------|-----------|
| `inspection-media` | ❌ | `{userId}/...` | `20260329000001_storage_buckets_and_policies.sql` |
| `maintenance-media` | ❌ | `{userId}/...` | same |
| `exports` | ❌ | `{userId}/...` | same |
| `leases` | ❌ | `{userId}/...` | same |
| `deposit-receipts` | ❌ | `{userId}/...` | same |
| `listing-screenshots` | ❌ | `{userId}/...` | same |
| `documents` | ❌ | `{userId}/...` | same |

**Rule:** App and API use short-lived signed URLs only. No permanent public file URLs.

### Railway API ownership checks

Every protected route must:

1. Validate JWT → `userId`
2. Verify resource ownership before DB/storage access
3. Return `404` for cross-user resource IDs (not `403` with hints)

| Route | Ownership check |
|-------|-----------------|
| `GET /api/exports` | `propertyId` owned by user |
| `GET /api/exports/:id/download` | export `user_id` match |
| `POST /api/exports/move-in` | property owned |
| `POST /api/exports/move-out` | property owned |
| `POST /api/exports/dispute-packet` | property owned |
| `GET /api/vaults/:propertyId/summary` | property owned |
| `GET /api/disputes/:propertyId/evidence-catalog` | property owned |
| `GET /api/properties/:propertyId/capabilities` | property owned |

Implementation: `requireAuth` middleware + `requireOwnedProperty` / `requireOwnedExport`.

### Secrets — never in mobile apps

| Secret | Allowed in iOS/Android | Server only |
|--------|------------------------|-------------|
| Supabase anon/publishable key | ✅ | — |
| RevenueCat public SDK key | ✅ | — |
| `SUPABASE_SERVICE_ROLE_KEY` | ❌ | ✅ Railway |
| RevenueCat webhook secret | ❌ | ✅ Railway |
| Google service account JSON | ❌ | ✅ server/CI only |
| Railway deploy secrets | ❌ | ✅ Railway |

Rotate any secret that was ever committed or shared in chat.

---

## P1 — Rate limits (Railway API)

| Endpoint | Limit | Key |
|----------|-------|-----|
| `GET /api/health` | 60/min | IP |
| `GET /api/exports` | 60/min | user |
| `GET /api/exports/:id/download` | 20/min | user |
| `POST /api/exports/move-in` | 3/hour | user + property |
| `POST /api/exports/move-out` | 3/hour | user + property |
| `POST /api/exports/dispute-packet` | 3/hour | user + property |
| `POST /api/webhooks/revenuecat` | 100/min | IP |

Export generation is CPU/memory intensive — limits prevent abuse (OWASP API4: Unrestricted Resource Consumption).

**MVP note:** Limits are **in-memory** (single Railway instance). They reset on deploy/restart and do not share state across replicas. Acceptable for early production; upgrade to Redis/Upstash/DB-backed limits before horizontal scale.

### Export status constraint

Allowed `exports.status` values (must match API + export v2):

```text
queued | processing | verifying | completed | failed
```

Migration: `20260522100000_security_hardening.sql` (`exports_status_check`)

---

## P2 — Abuse + file safety

### Uploads (client → Supabase Storage)

- Max image size: 10–15 MB (enforce in client; validate server-side where applicable)
- Allowed types: `jpg`, `jpeg`, `png`, `heic`; `pdf` for documents only
- Reject unknown MIME types
- Server-generated storage paths — never trust client file paths

### PDF exports

- Max export attempts per hour (rate limits above)
- Pipeline timeout / fail cleanly
- `error_message` stored internally only; generic message to client
- Download signed URLs expire in 15 minutes

### Webhooks

- `REVENUECAT_WEBHOOK_SECRET` required in production
- Constant-time token comparison
- Log event id/type
- Idempotent entitlement updates (when implemented)
- Never grant Pro from unsigned body

---

## Observability

- Every request gets `X-Request-Id` (also in logs)
- Structured logs: route, userId (when authed), status, timing
- No stack traces in API responses
- Internal errors logged server-side only

---

## Pre-release QA

Run manual two-account isolation: `docs/SECURITY_QA.md`

Automated API tests: `movemark-api` → `npm test`

```bash
cd movemark-api && npm test
```

Verify:

- [ ] Wrong user cannot list another user's exports
- [ ] Wrong user cannot download another user's export
- [ ] Missing auth → 401
- [ ] Invalid property → 404
- [ ] Rate limit → 429
- [ ] Webhook without secret (production) → 401
- [ ] Signed download URLs expire (15 min)

---

## Release sign-off

| Gate | Owner | Date | Pass |
|------|-------|------|------|
| [ ] RLS enabled + policies verified on live Supabase (not docs only) | | | |
| [ ] Export status constraint includes `verifying` | | | |
| [ ] Storage buckets private | | | |
| [ ] Railway env secrets set (no service key in apps) | | | |
| [ ] API ownership middleware deployed | | | |
| [ ] Rate limits enabled (MVP in-memory; document scale plan) | | | |
| [ ] Security QA script run (2 accounts) | | | |
| [ ] `npm test` green | | | |

**Production-ready when all P0 items pass and pre-release QA is signed off.**
