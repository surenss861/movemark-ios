# Security pre-merge runbook

Branch `movemark-security-hardening` is **build-green** but **not merge-ready** until live checks pass.

## Merge gate (current)

```text
✅ Branch build/test passes
✅ verifying status fixed in migration
✅ RLS enabled on sensitive tables (rowsecurity = true)
✅ RLS policies exist (per-table policy_count >= 1)
⬜ Policy definitions enforce ownership (Step 4 SQL — no bare `true`)
⬜ exports_status_check verified live includes verifying
⬜ Two-account test passes (the real proof)
⬜ Railway REVENUECAT_WEBHOOK_SECRET + APP_ENV=production + redeploy
⬜ Webhook missing/bad secret → 401
⬜ Export + health rate limits → 429
⬜ Leaked Google service account key rotated
```

**Note:** Policy count only proves policies exist — not that they are correct. The two-account test answers: *Can User B access User A's data?* That must be **no** every time.

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

**Account A:** create property, upload proof, generate export.

**Account B:** try A's property ID, export list, export download, create export on A's property, any signed URL from A.

Expected every time:

```text
401 — not logged in
403/404 — logged in but not owner
never — signed URLs, file access, or A's metadata
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
