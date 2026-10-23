# Disaster recovery — Backblaze B2

Recovery needs only B2, the backup key and this repository: no Neon account, no Railway, no Mac in particular.

## What is kept

| B2 bucket | Contents | Written by |
|---|---|---|
| `movemark-db-backups-prod` | `db/movemark-production-<UTC>.mmbk` (+ `.sha256`, `.json`): `pg_dump` of the whole database — schema, rows, grants, migration ledger, Neon Auth identities — encrypted (AES-256-GCM, 8 MiB authenticated chunks) | `scripts/dr/backup.py --database-only`, then `offsite.py push-db` (re-downloaded and hash-checked) |
| `movemark-evidence-backups-prod` | `objects/<bucket>/<key>`: every evidence photo, thumbnail, immutable source, document and report, each encrypted on its own with its path bound in; `manifests/<UTC>.tsv.mmob`: the complete set at that time (bucket, key, bytes, SHA-256, source ETag), encrypted | `offsite.py sync-evidence` (uploads only what changed) |

Both buckets are private, use Object Lock with a 30-day default retention (nothing can be overwritten or
deleted inside the window, not even with the job's own keys), and each has its own application key
restricted to it. The backup key (32 bytes) lives in the password manager and in the backup job's secrets —
never in Neon, B2 or the repository; without it the backups are unreadable.

## Schedule (Railway cron service, production)

- every 6 hours: database backup → push (4 a day);
- daily: evidence sync (incremental);
- retention: Object Lock keeps everything 30 days; keep one database backup and one manifest per month for
  12 months (B2 lifecycle rules on the buckets).

## Recover (B2-only)

```
export B2_ENDPOINT=… B2_DB_BUCKET=… B2_DB_KEY_ID=… B2_DB_APP_KEY=… \
       B2_EVIDENCE_BUCKET=… B2_EVIDENCE_KEY_ID=… B2_EVIDENCE_APP_KEY=…
../movemark-api-py/.venv/bin/python scripts/dr/offsite.py pull --key-file <key> --to <empty dir>
../movemark-api-py/.venv/bin/python scripts/dr/restore.py --archive <dir>/<newest>.mmbk --key-file <key> \
    --workdir <empty dir 2> --evidence <dir>/evidence [--keep-running]
```

`pull` checks the archive's SHA-256 and every object against the manifest. `restore.py` builds a blank
PostgreSQL 18 cluster, restores into it with production's roles and settings, and proves: archive hash and
every chunk's tag, every object, row counts, the schema fingerprint equal to a from-zero build at the
backup's ledger head, every referenced storage path present, every immutable source's SHA-256. Upload
`<workdir>/objects` to any S3-compatible store with the same bucket names, point the API's `DATABASE_URL`
and `AWS_*` at them, and it serves the app.

## Drill

`scripts/dr/b2_drill.py` runs all of it on the `dev` branch and prints `B2_DRILL PASS/FAIL`: seeds the QA
account, backs up, pushes to B2, recovers from B2 alone into a blank database and blank object storage,
boots the API there (`/api/ready`, vault summary, signed downloads byte-compared with what was seeded), and
deletes the QA account.

| Date | B2 | Result |
|---|---|---|
| 2026-10-23 | local S3 stand-in (account pending) | PASS — 8 rows, 5 objects; backup 20 s, recovery 3 s; API ready; 4/4 evidence files served byte-identical; dev zeroed after |
