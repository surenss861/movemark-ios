# Security pre-merge runbook

Branch `movemark-security-hardening` is **build-green** but **not merge-ready** until live checks pass.

## 1. Supabase (live project)

Run `scripts/security/pre-merge-verify.sql` in the SQL Editor.

Confirm:

- `exports_status_check` includes `verifying`
- All listed tables show `rowsecurity = true`

## 2. Railway (production API)

Set:

```text
REVENUECAT_WEBHOOK_SECRET=<your_secret>
APP_ENV=production
```

Redeploy API. Then verify:

```bash
# No secret / bad secret → 401
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://<api>/api/webhooks/revenuecat \
  -H "Content-Type: application/json" -d '{}'

curl -s -o /dev/null -w "%{http_code}\n" -X POST https://<api>/api/webhooks/revenuecat \
  -H "Authorization: Bearer wrong" -H "Content-Type: application/json" -d '{}'
```

## 3. Two-account manual QA

Follow `docs/SECURITY_QA.md`.

Account B must never access Account A:

- property IDs
- export list/download
- signed URLs
- export creation on A's property

Expected: `401` (no auth), `403`/`404` (wrong owner).

## 4. Abuse checks

- Spam export create → `429`
- Spam `GET /api/health` → `429`
- Invalid webhook → `401`

## 5. Secrets

- [ ] No service role key in iOS/Android builds
- [ ] Leaked Google service account JSON rotated

## Merge gate

```text
✅ Branch build/test passes
✅ verifying status fixed in migration
⬜ Live Supabase migration + RLS verified
⬜ Railway webhook secret + redeploy
⬜ Two-account cross-user test passes
⬜ 429 + webhook 401 confirmed
⬜ Google key rotated
```

When all green:

```bash
git checkout main && git pull
git merge movemark-security-hardening
git push
```

Merge **security before export v2**.
