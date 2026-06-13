# Security pre-merge runbook

Branch `movemark-security-hardening` is **build-green** but **not merge-ready** until live checks pass.

## Merge gate (current)

```text
✅ RLS enabled
✅ Policies exist
✅ Policy definitions pass (live audit)
⬜ exports_status_check includes verifying
⬜ Railway webhook bad/missing secret → 401
⬜ Two-account cross-user test passes
⬜ Export spam → 429
⬜ Health spam → 429
⬜ Leaked Google service account key rotated
```

**Highest-risk path:** Account B must **not** download Account A's export PDF (signed URL or file bytes).

**Dual protection model:**

```text
Client Supabase access → RLS (auth.uid() / property ownership)
Railway API access     → requireAuth + ownership middleware (service role bypasses RLS)
```

Both layers are required. RLS audit passed live; two-account test still proves it in practice.

---

## 1. Supabase (live project)

Run `scripts/security/pre-merge-verify.sql` in the SQL Editor.

### A) Export status constraint

```sql
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.exports'::regclass
  AND conname = 'exports_status_check';
```

Must include: `queued`, `processing`, `verifying`, `completed`, `failed`.

If missing, run the `ALTER TABLE` block at the top of `pre-merge-verify.sql`.

### B) RLS enabled

All sensitive tables → `rowsecurity = true` (confirmed live).

### C) Policies exist

`pre-merge-verify.sql` Step 3 lists policies per table. Each table needs `policy_count >= 1`.

Healthy live result (example):

```text
evidence_files      5 policies
exports             5 policies
inspections         5 policies
profiles            3 policies
properties          5 policies
property_documents  5 policies
rooms               5 policies
```

### D) Policy definitions enforce ownership

Run Step 4 in `pre-merge-verify.sql`:

```sql
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'properties', 'rooms', 'inspections',
    'evidence_files', 'property_documents', 'exports')
ORDER BY tablename, policyname;
```

**Good:** `auth.uid() = user_id` or property ownership via join.

**Bad:** bare `true`, `using (true)`, or `auth.role() = 'authenticated'` without user scoping.

**Live audit (passed):** policies tie rows to `auth.uid() = user_id` or property ownership via `properties.user_id`. No wide-open policies observed.

### Post-merge cleanup (not blockers)

- **Duplicate `ALL` + per-cmd policies** on some tables (`properties_own_all`, `exports_own_all`, etc.) — redundant but safe; simplify to one style later for easier audits.
- **`exports_insert_own` allows `property_id IS NULL`** — OK if API always sets property; tighten later so move-in/move-out/dispute exports always require `property_id`.
- **In-memory rate limits** — upgrade to Redis/Upstash before horizontal scale.

---

## 2. Railway (production API)

Set:

```text
REVENUECAT_WEBHOOK_SECRET=<your_secret>
APP_ENV=production
```

Redeploy API.

Webhook tests (replace `YOUR_API_URL`):

```bash
# No secret → 401
curl -i -X POST https://YOUR_API_URL/api/webhooks/revenuecat \
  -H "Content-Type: application/json" \
  -d '{}'

# Bad secret → 401
curl -i -X POST https://YOUR_API_URL/api/webhooks/revenuecat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer wrong-secret" \
  -d '{}'
```

---

## 3. Two-account manual QA (required — the real proof)

Follow `docs/SECURITY_QA.md`.

**Account B** (logged in as different user):

1. List/fetch A's property
2. List/fetch A's rooms
3. List/fetch A's evidence files
4. Fetch A's export (list + by ID)
5. **Download A's export PDF** ← highest risk
6. Create export using A's `propertyId`

Expected every time:

```text
404 / 403 / empty result
no signed URL
no metadata leak
no report download
```

If B can see or download anything belonging to A, **do not merge**.

---

## 4. Abuse checks

- Spam export create → `429`
- Spam `GET /api/health` → `429`

---

## 5. Secrets

- [ ] No service role key in iOS/Android builds
- [ ] Leaked Google service account JSON rotated in GCP

---

## Merge (only when all gates green)

```bash
git checkout main && git pull
git merge movemark-security-hardening
git push
```

Merge **security before export v2**.
