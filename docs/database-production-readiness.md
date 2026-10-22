# MoveMark database — production-readiness report

Production Database Hardening gate, 2026-10-22. Everything below was proven on Neon `dev` (0950–0980 applied there through the runner), a disposable Neon
benchmark branch (deleted afterwards) and local builds of the same migrations. **Production was not changed
by this gate** except for creating its 7 private storage buckets, which happened in the earlier promotion
step.

## Verdict

**GO**, after your review, to promote migrations 0950, 0960, 0970 and 0980 to production through
`neon/migrate.py`. They are schema-only, production holds no rows, and all four passed every gate on dev.

**NO-GO** for pointing Railway production at Neon, or for real users, until all of these are done:

1. Migrations 0950–0980 are applied to production by the runner, and the runtime roles' DSNs are set on Railway.
2. Production auth has its own email provider (SMTP and sender domain) and an HTTPS password-reset link
   domain with trusted origins. `allow_localhost` and the shared OAuth provider are already gone.
3. Unbounded reads are fixed: snapshot v2 (summary plus on-demand pages), an aggregated vault summary,
   signed URLs by row id, and paginated lists.
4. The Backblaze B2 backup is running and a B2-only restore drill passes: blank database plus blank storage,
   and the API boots against them.
5. Production Neon settings: scale-to-zero off, 0.5–4 CU, history retention 7 days.
6. The Production Security & Abuse-Resistance gate (rate limits, adversarial suite) passes.

## Production promotion record (2026-10-22)

| Step | Result |
|---|---|
| Pre-apply (09:14Z) | `status` 32 applied / 4 pending (0950–0980); `check` passed, but before the fix it did not compare the live schema while migrations were pending |
| First apply | 0950 and 0960 applied; **0970 failed**, because its policies already existed |
| Finding | 0950–0980 had been executed on the production database **outside the runner**, within minutes of each file being written or committed (compute woke at 07:38–07:44 and 08:26–08:31). Catalog transaction IDs prove the objects predate the runner's ledger rows. No credential, environment variable or hook on the development machine targets production |
| Runner fix | `check` now always compares the live schema with a from-zero build of its recorded migrations before anything pending is considered (regression test in `neon/tests/test_migrate.py`) |
| Repair | Neon point-in-time restore of production to 07:35:00Z (09:21:56Z). The out-of-band state is preserved as branch `production-out-of-band-2026-10-22` (`br-quiet-dust-b5dxh8dp`). Endpoint and buckets unchanged. The restore reverted the auth changes, so they were re-applied |
| Re-apply | `status` 32/4, `check` with no drift, then the runner applied 0950 → 0960 → 0970 → 0980; post-check: 36 applied, live schema equals the from-zero build |
| Verification | Role/grant audit matches the tested per-process sets exactly. Runtime roles: no BYPASSRLS, ownership, CREATE, `neon_auth` or group membership. Each privileged function is callable only by its process. New tables and functions are private (global function default revoked). Production fingerprint `6ea7f35f…` (435 facts) is **identical to dev**. External smoke: anonymous and forged-token Data API requests refused, anonymous privileged RPC refused, all buckets 403 to anonymous |

Neon production settings (approved, applied 2026-10-22):

| Setting | Before | After |
|---|---|---|
| Autoscaling | 0.25 – 8 CU | 0.5 – 4 CU |
| Scale-to-zero (`suspend_timeout_seconds`) | 0 (default: suspend after 5 min) | −1 (never suspends) |
| History retention (project-wide) | 21,600 s (6 h) | 604,800 s (7 days) |

Production auth: `allow_localhost` off, shared Google OAuth removed; email and password only. The shared email
sender remains until Postmark is configured.

## What changed

| | |
|---|---|
| `0950_index_hardening.sql` | 19 indexes, each justified by a query plan: unindexed FKs on the ownership chain, path lookups (hash indexes), account-deletion filters, the expiry of tickets nobody finalized or abandoned |
| `0960_role_and_grant_hardening.sql` | New tables private by default. `authenticated` gets exactly the operations the apps perform. `movemark_api`/`movemark_worker` runtime roles. `delete_auth_user()`. Pinned `search_path`. `pg_stat_statements` in a private schema |
| API | Exact-match abandon check, auth-user deletion via the function, role-level timeouts, `application_name` |
| API correctness | Export lease fencing + heartbeat + 600 s default timeout; free move-in quota re-decided under a per-user lock; sweeper for upload tickets nobody finalized or abandoned; capabilities uses counts |
| Tooling | `scripts/db/` (synthetic data, plan bench, load gate, runtime-role provisioning), `scripts/dr/` (backup, restore drill) |

Proof on dev after applying both migrations, with the API as `movemark_api` and the worker as `movemark_worker`:

| Check | Result |
|---|---|
| Runner upgrade path | Identical to a from-zero build (434 schema facts), no drift |
| Schema tests (local) | 110/110 |
| API tests | 216/216 |
| Data API e2e (real JWTs) | 53/53 |
| Object Storage gate | 44/44 |
| iOS lifecycle, 17 steps | Passed: token refresh, abandon, docs, worker PDF, second-user isolation, deletion; dev left at zero |

## Schema and integrity findings

- **Sound:**
  - every status/type column has a CHECK;
  - evidence provenance is all-or-nothing, with a hash format check and a 25 MB cap;
  - credit balances can't go negative;
  - ownership and key columns are NOT NULL (two nullable columns are nullable by design);
  - 0930's cross-property protections are in place and covered by the poisoning test (another account stays deletable).
- **Intentional `ON DELETE NO ACTION` everywhere inside the domain.** Deletion runs through `delete_user_owned_data` in a fixed order. Only the billing tables cascade from `neon_auth.user`.
- **Open:**
  - `user_id` columns other than the billing tables have no FK to `neon_auth.user`;
  - account deletion goes through the API, so a user removed only in Neon Auth would leave rows behind;
  - per your rule, the reconstructed tables (`disputes`, `move_out_checklist_state`) are kept even though nothing writes them today.

## Role / grant matrix (after 0970 + 0980)

| Role | Login | Tables (S/I/U/D) | Row access | Functions |
|---|---|---|---|---|
| `anonymous` | no | none | — | none |
| `authenticated` (Data API) | via JWT | properties SIU · rooms SI · inspections SI · inspection_items SIUD · inspection_item_tags SID · evidence_files SID · maintenance_issues SIUD · property_documents SID · profiles SIU · move_out_checklists SIU · issue_tags S · exports S · disputes S · dispute_evidence_links S | own rows (RLS); `disputes`/links SELECT only because 0930's maintenance update policy reads them | `get_property_snapshot` |
| `movemark_api` | yes | S: properties, rooms, inspections, inspection_items, inspection_item_tags, issue_tags, maintenance_issues, disputes, user_report_credits · SD: evidence_files, property_documents, dispute_evidence_links · SI: exports · SIU: user_entitlements · SIUD: storage_upload_tickets | named policy per table for this role only, **no BYPASSRLS** | consume/grant_report_credit, delete_user_owned_data, delete_auth_user |
| `movemark_worker` | yes | S: properties, rooms, inspections, inspection_items, inspection_item_tags, issue_tags, evidence_files, property_documents, maintenance_issues · SU: exports, storage_upload_tickets | named policy per table for this role only, **no BYPASSRLS** | claim_next_export_job, reap_stuck_export_jobs |
| `movemark_backend` | no | none (kept as an empty group) | — | none |
| `neondb_owner` | yes | owner | — | owner; migrations only (`neon/migrate.py`), never Railway |

Neither runtime role:
- owns anything;
- holds a grant option;
- can create in the database or a schema;
- can truncate;
- can switch to the owner;
- can read `neon_auth`.

Proven by logging in with each runtime credential (`neon/tests/test_reconstruction.py`). The API suite runs as `movemark_api` and the worker suites as `movemark_worker`. Each uncertain grant was revoked in turn and the suites rerun; unused grants were dropped.

New tables and functions created by the migration role are private to every role. 0970 also fixes a real gap here: 0900's per-schema `REVOKE EXECUTE ... FROM PUBLIC` never applied, because per-schema defaults can only add to global ones. 0970 revokes the default globally.

SECURITY DEFINER audit (0980):
- owner is the migration role;
- `search_path = pg_catalog, public, pg_temp`;
- each function is executable only by the process that calls it;
- no dynamic SQL;
- all parameters typed;
- the reaper refuses windows or attempt counts that would requeue live jobs.

Production auth (2026-10-22): `allow_localhost` is off and the shared Google OAuth provider is removed; neither app uses OAuth. Still open: the email provider and the HTTPS reset-link domain.

Onboarding: fixed. Completion is recorded when the first proof is saved, and a UI test relaunches on the receipt; it fails without the fix.

## Indexes: plans that justified them

All figures are medians of EXPLAIN (ANALYZE, BUFFERS) at 1.65M evidence rows. App queries were measured as `authenticated` under RLS.

| Query | Before | After (local) | Neon PG18 |
|---|---:|---:|---:|
| Account deletion | 1983 ms | 10 ms | 20 ms |
| Abandon "referenced?" check | 1478 ms | 0.06 ms | 0.06 ms (`lower()` form: 621 ms) |
| Signed-URL lookup by path | 238 ms | 0.04 ms | 0.05 ms |
| Evidence by item | 20 ms | 0.01 ms | 0.04 ms |
| Items by room | 13 ms | 0.01 ms | 0.05 ms |
| Rooms by property | 8.6 ms | 0.02 ms | 0.07 ms |
| Snapshot, typical property (60 photos) | 11 ms | 2.1 ms | 2.3 ms |
| Snapshot, 50k-photo property | 752 ms | 709 ms | 618 ms |
| Export claim / reaper | — | 0.05 ms | 0.2 ms |

- **Removed:** nothing.
- **Candidates to drop:** `idx_exports_user_id_id` and `idx_exports_user_prop_dispute_type` were unused by every benchmarked query. Confirm with `pg_stat_user_indexes` on production before dropping.

## Synthetic dataset

| Entity | Rows |
|---|---:|
| Users | 20,000 |
| Properties | 25,000 |
| Rooms | 250,000 |
| Inspection items | 1.03M |
| Evidence | 1.65M |
| Item tags | 300k |
| Upload tickets | 200k |
| Exports (incl. 20k queued) | 120k |
| Maintenance issues | 100k |
| Documents | 75k |

The dataset also includes one "years of use" property with 50k photos. Total size is 1.17 GB on Neon.

## Load / concurrency gate (Neon, `movemark_api` through the pooler)

| Sessions | ops/s | Ping p50 (round-trip baseline) | Evidence write p50 / p99 |
|---:|---:|---:|---:|
| 10 | 45 | 138 ms | 236 / 277 ms |
| 25 | 126 | 128 ms | 219 / 259 ms |
| 50 | 229 | 143 ms | 246 / 294 ms |
| 100 | 443 | 139 ms | 240 / 491 ms |

**Throughput scaled linearly and the medians stayed flat.** The latency is the round trip from the test machine to us-east-2, not database work. `pg_stat_statements` shows:

- 0.28 ms average execution per statement (169k statements);
- an evidence write (item + 2 photos) costs about 2.2 ms of database time;
- account deletion averages 34 ms, with a 481 ms maximum while competing with 100 writers.

**No database bottleneck was reached.** The first limits are network distance and the API's client pool (see below).

**Invariants held under concurrency:**
- 424 credit-funded enqueues spent exactly 424 credits (3,356 correctly refused, no negative balance);
- 424 claims, none duplicated;
- 312 accounts deleted while 100 other sessions kept writing, with nothing left behind;
- 0 deadlocks, serialization failures or timeouts.

**Slowest queries:**
- the snapshot of a very large property (about 0.6 s at 50k photos);
- `delete_user_owned_data` under contention;
- the dispute-catalog photo list (26 ms at 50k photos, unbounded).

## Pool / connection budget

Neon's pooler (PgBouncer, transaction mode) keeps a separate server pool for each role and database, sized from the compute's `max_connections`. The benchmark compute reported 901 while it was scaled up. The client side accepts up to 10,000 connections. The budget to respect, at the **minimum** CU:

```
api_replicas × PG_POOL_MAX(api)        ≤ server pool for movemark_api
worker_replicas × PG_POOL_MAX(worker)  ≤ server pool for movemark_worker
```

- **Set the API's `PG_POOL_MAX` to 20 per replica.** The vault summary fans out to 7 parallel queries and capabilities to 4, so with 10 per replica, two simultaneous cache misses already queue for the 10 s pool timeout.
- **Keep the worker at 10.** It runs one job at a time and claims 2 per tick.
- Timeouts come from role settings, so they hold through PgBouncer. A session `SET` would land on whichever server connection ran it.

## Migration strategy

- **Forward-only and immutable once applied.** The runner refuses checksum changes, out-of-order files and uncommitted files. Production changes need `--production --confirm br-solitary-glade-b5nc31al`.
- **Every apply proves itself first.** The runner builds from zero and compares the upgrade path to that build before applying anything. Test on a Neon branch before production.
- **Changes to populated tables go additive → backfill → switch → remove.** On populated tables, use `CREATE INDEX CONCURRENTLY` in its own non-transactional step. 0950 uses plain `CREATE INDEX` only because production is empty.
- **To add:** a CI job running `neon/tests/test_migrate.py` and `test_reconstruction.py` on every push (local Postgres only).

## Production Neon configuration (recommendation)

Production today has 0.25–8 CU autoscaling, **scale-to-zero on** (`suspend_timeout` default) and **6-hour history retention**.

| Setting | Recommendation | Why |
|---|---|---|
| Scale-to-zero | **Off** for production | No cold start on the first request; dev keeps scale-to-zero |
| Autoscaling | **0.5 – 4 CU** | Measured database time is about 0.3 ms per statement, so 443 ops/s used roughly a quarter of one core. A 0.5 CU minimum (2 GB RAM) holds the hot working set of the 1.2 GB synthetic dataset. Raise the floor if `pg_stat_statements` shows cache misses |
| History retention (PITR) | **7 days** (the Launch plan maximum; 14–30 days needs Scale) | 6 hours is too short to notice and undo a bad change |
| Read replicas | **None** | No measured read pressure; can be added later without copying storage |

## Backup / PITR plan

| Layer | What | RPO | RTO |
|---|---|---|---|
| Neon PITR | Branch restore to any second in the retention window | Seconds | Minutes |
| Independent backup (`scripts/dr/backup.py`) | Encrypted archive: full database (incl. `neon_auth` identities) + every object, with a SHA-256 manifest | Backup interval: **daily** recommended (every 6 h for a tighter RPO) | Measured: 1.2 GB / 3.6M rows restored and verified in 45 s, plus object upload and app repointing; target ≤ 4 h for total Neon loss |

**Restore drill: PASS.** The restore used only the archive and the key: no Neon account, CLI or network. It ran into a blank PostgreSQL 18 cluster and verified:
- the chunk authentication tags;
- the object manifest;
- row counts;
- the ledger head (0960);
- the schema fingerprint against a from-zero build;
- every referenced object and every evidence source SHA-256.

A tampered archive and a wrong key were both refused.

To recover onto a new provider:
1. Run the restore.
2. Upload `objects/` to any S3-compatible store with the same bucket names.
3. Point `DATABASE_URL` and the `AWS_*` variables at the new locations.
4. Run identity on a self-hosted Better Auth over the restored `neon_auth` tables.

**Still needed (your decision):**
- the backup destination: an account outside Neon, e.g. AWS S3, Backblaze B2 or Cloudflare R2, with versioning or object lock;
- where the backup key lives (the team password manager);
- where the scheduled job runs (a Railway cron service is the simplest option).

## Remaining database risks

1. **Large-property snapshot.** `get_property_snapshot` returns a property's whole history. That's 2 ms at 60 photos but about 0.6 s and several MB at 50k, and the apps call it on launch, on property switch and after saves. The vault "other rentals" summary runs a full snapshot per property just to get two counts. The fix is either snapshot pagination (client work on both apps) or a per-property evidence cap. The Data API's `db-max-rows` is not a fix on its own, because it truncates silently.
2. **Unbounded list reads.** These grow with use but are fine at realistic sizes:
   - evidence by property (iOS);
   - the dispute-catalog photo list (API);
   - documents fetched only to find which types exist.
3. **Observability is partial.** `pg_stat_statements` is installed and `/api/ready` checks the database. Alerting on slow queries, pool saturation, lock waits, deadlocks and storage growth belongs to the observability phase.
4. **Auth-user FKs.** These are absent (see Schema and integrity findings above).
5. **Production auth defaults:**
   - Neon's shared email sender;
   - `allow_localhost: true`;
   - shared-key Google OAuth;
   - no trusted domains.

   These are for the iOS production phase.
