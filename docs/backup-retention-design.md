# Backup retention and deletion tracking

**Status: proposed. Nothing here is live.** Built and tested on development only, on 2026-11-07. No backup job, B2 bucket, lifecycle rule, Object Lock setting, Railway service or production database was changed. `docs/compliance/launch-checklist.md` P0-1 and P0-2 stay open until the rollout below is finished.

## The short answer

- **Can MoveMark promise 90 days today? No.** Backup copies of files have no end date, and monthly database backups last 365 days.
- **Can it after rollout? Yes, for the copies in B2,** counted from when an item stopped being live. Object Lock doesn't prevent it, because a 30-day lock always ends before day 90.
- **From when?** From step 9 of the rollout: the first real prune has run, a read-back of every file version shows nothing past the limit, and the copies outside B2 are dealt with. Not on the day the code ships.
- **Three things the promise doesn't cover**, and the policy has to say so or stay silent on them: when Backblaze physically erases a deleted file (undocumented), a single photo or document returning after a restore, and an account deleted in the hours just before a total database loss.

## The numbers

| Setting | Days | Why |
|---|---|---|
| Limit in the policy | 90 | The maximum proposed in the launch checklist |
| Restore window (`Policy.window_days`) | 80 | Oldest restore point kept: backups, manifests and the files they need |
| Lifecycle backstop | 84 + 1 | Removes aged `monthly/` and `manifests/` files if the prune stops, by about day 86 |
| Alarm | 85 | Anything still present past this needs a person |
| Deletion tracker | 120 | Must outlive every backup that could hold a deleted account |
| Object Lock (documented, unconfirmed) | 30 | Must stay below the restore window; `Policy` refuses otherwise |

An item that stops being live on day X is last listed in a manifest no later than X, plus the length of one sync. It becomes removable on day X + 80, the daily prune takes it by X + 81, and nine more daily runs can fail before X + 90.

**Cost of this choice, for the owner to accept:** the oldest possible restore goes from about a year to 80 days. `db/` stays about 36 days. `monthly/` shrinks to one or two extra restore points.

## Retention (`scripts/dr/retention.py`)

A dry run by default. It reads every version in both buckets, decrypts every manifest inside the window, and prints counts and ages only, because object names contain user ids. `--apply` also needs both bucket names typed out. Both plans are made before anything is deleted, so a refusal in one bucket stops both.

**What goes.** A backup or manifest past the window, never the newest. A file version that no manifest from the last 80 days needs. A deletion-log batch past 120 days, from the oldest end only, and only if no kept backup is older. A hide marker once nothing under its name is left, because the name itself holds a user id.

**Shared and replaced objects.** Storage isn't content-addressed: `objects/<bucket>/<key>` is one name per object, so two identical photos are two copies and one can go without touching the other. The sharing that matters is a name kept across versions. A source overwrite makes a new B2 version, and manifests record a SHA-256, not a version id. Each stored version carries that SHA-256 as metadata, so the prune matches versions to manifests by content. An older version that any kept manifest still names stays. One with unreadable metadata stays and raises an alarm.

**Object Lock.** It asks about each version through the two documented calls and leaves locked versions for a later run. It never sends a governance bypass. A version can only be locked for 30 days from upload, and upload comes before it stopped being live, so the lock always ends before day 90 unless someone extended it. That case, and a legal hold, raise an alarm.

**Deleting.** By version id only, because a delete without one writes a hide marker and removes nothing. Uploads go before markers, so a file can't reappear halfway. Afterwards it lists every version again to confirm they are gone.

**Fails closed.** It deletes nothing in either bucket if: a kept manifest can't be read or decrypted; the newest manifest or newest complete backup is over 48 hours old, which also catches a wrong clock; a file is dated in the future; something the newest manifest lists is missing, hidden or the wrong size; or the newest manifest shrank by half or the plan removes over 25% of stored versions. The last two need `--allow-large` after review. Wiped live storage looks exactly like mass deletion, and a sync would dutifully write empty manifests. At today's small scale, one account deletion can trip the 25% check. That is intended.

**Exit codes.** 0 clean. 2 refused. 3 ran, but a person is needed before the limit is reached.

**Why not lifecycle rules alone.** A rule can't know what a manifest still needs, and `daysFromUploadingToHiding` also hides the current version, so on `objects/` it would delete live data. It must never be set there. Rules work as a time-based backstop only, and only for files that are hidden or superseded. **A file deleted at the source is still the current version in B2, so the prune is the only thing that removes it.** Losing the prune for more than nine days breaks the promise, so its alarm must reach a person.

## Deletion tracking

The record has to survive a restore, so it can't live only in the database being restored. It also shouldn't depend on the API, since that repository is out of scope here and a code path can be forgotten. It has two parts.

**1. Capture, in the database (`neon/migrations/1060_deletion_tombstones.sql`).** `public.deletion_tombstones` holds a kind, a hash and a day. It is written inside `delete_user_owned_data`, `delete_auth_user` and an `AFTER DELETE` trigger on `properties`, so it commits with the deletion and the API needs no change. The account is recorded at the first step, so a deletion that fails partway is still finished by a replay. Clients and runtime roles get no access. RLS is on with no policies.

**2. Durable copy, outside the database (`scripts/dr/deletion_log.py export`).** Each backup run appends a batch to `deletion-log/` in the B2 DB bucket, under Object Lock. It holds only what the log doesn't have yet, compared by content, so a database rewound by a restore can't cause a deletion to be skipped. Batches are sealed with the backup key and chained by SHA-256, so a removed, altered or reordered batch is detected. A run with nothing new still writes a batch, which is how a replay tells "no deletions" from "the export had stopped".

It shares a bucket with the backups on purpose. If B2 is lost there is nothing to restore, so the log and the backups fail together, which is the safe way round. It also needs no new bucket or key.

**The identifier.** `SHA-256("movemark-deletion-v1:" + lower(id))`. No email, name or raw id. Replay works by hashing what it finds in the restored database. This is pseudonymous, not anonymous: anyone who already holds an id can test for a match. Ids are random UUIDs, so a hash can't be guessed back into an id.

**Tracker retention.** 120 days. A backup can't be older than 90 days, so every tombstone outlives every backup that could hold its subject. In B2, the prune removes old batches. In the database, the next deletion clears expired rows, so a row can sit past 120 days if no one deletes anything. No runtime role was given delete rights just for this. Expired rows also leave the backups as those age out.

### Restore: fence, replay, verify

`restore.py` fences every restore: `movemark_api`, `movemark_worker` and `movemark_backup` can't log in, and the Data API roles lose `public`. The fence is a role attribute and a schema grant, so it holds without any API change. It records exactly what it took away, so lifting it adds nothing. Files stay in `<workdir>/objects-fenced`, so an operator can't upload them by accident.

Replay deletes matched accounts through the same functions the API uses, and matched rentals through `delete_property_owned_data`. It removes their files by path, which catches files no row points at, and removes their rows from the manifest an operator uploads from. It then proves nothing remains, in every public table with a `user_id` column as well as `neon_auth."user"` and `profiles`, so a future table is covered automatically. Only then does the fence lift. Replay is safe to run twice.

It refuses a log that fails verification, and there is no override. A log that doesn't span the restore point means some deletions can't be known. `--accept-log-gap <reason>` continues, with the reason in the receipt. **That is an owner decision, because deleted accounts may return.**

### Runbook steps to add at rollout

1. If the old database is reachable, run `deletion_log.py export` against it first. This closes the gap described below.
2. `deletion_log.py pull --key-file <key> --to <dir>`.
3. `restore.py … --deletion-log <dir>`. Do not skip this.
4. Confirm `SERVICE_UNFENCED` and keep `replay-receipt.json`.
5. Upload `<workdir>/objects` and start the service.

**A Neon point-in-time restore needs the same step.** It doesn't pass through `restore.py`, and a restore in place is live immediately. Stop the API and worker first, then `deletion_log.py fence`, then `replay` with `--as-of` set to the restore time. `fence` and `replay` refuse the production endpoint unless `MOVEMARK_REPLAY_PRODUCTION` is set to the production branch id, which is meant for an owner-approved incident only.

## Known limits

- **The export gap.** A deletion exists only in the database until the next export, up to 6 hours. If the database were lost completely in that window, the restored backup wouldn't know about it, and the account would return. Only a total loss causes this: if the old database is reachable, runbook step 1 closes it. The real fix is an API change, writing a tombstone straight to B2 before account deletion reports success. It wasn't built here because the API repository is out of scope. Exporting every 15 minutes would narrow the window.
- **Single photos and documents aren't tracked.** Accounts and rentals are. A single item deleted after a backup returns if that backup is restored, until the backup expires. The Privacy Policy text below says so. Adding them needs the API's delete logic mirrored in replay.
- **A failed deletion is still a deletion.** If an account deletion fails partway and the person keeps using the account, a later replay deletes it. They asked for that, but they may not expect it to happen later.
- **Prune cost.** It reads every kept manifest on each run, about 320 at four a day. Fine at today's size. Past roughly a million objects, keep only manifests paired with a kept backup.
- **`pull` only fetches the newest set.** Restoring an older backup needs an older manifest chosen by hand, as it does today.

## What Backblaze documents

Read 2026-11-07 from backblaze.com, through a summarizing tool and search excerpts. Check exact wording before quoting any of it publicly. Sources are at the end.

### Verified in official documentation

| Topic | What the docs say | What it means here |
|---|---|---|
| Versions | Buckets are always versioned. Hiding adds a version "without removing any of the history". | Listing current files misses what matters. The prune lists versions. |
| Hidden files | Still downloadable by file id and still count as stored. | Hidden is not deleted. |
| Real deletion | `b2_delete_file_version` "permanently deletes the file version and all of its data as if you never uploaded that version", and can't be undone. S3 delete with a version id: "permanently deleted". Without one: "a delete marker will be inserted". | Delete by version id only. |
| Capabilities | `deleteFiles` to delete. `bypassGovernance` plus an explicit flag to delete a governance-locked version. `readFileRetentions` and `readFileLegalHolds` to see lock state; listing results are "filtered based on application key capabilities". | The prune key needs the first and last two, and never `bypassGovernance`. |
| Object Lock | Governance can be overridden by keys with the capability. Compliance "cannot be removed by any user" and can only be extended. Lock can't be disabled on a bucket once on. Changing the bucket default doesn't affect existing files. | Locks only delay deletion. The default can't be lowered for files already uploaded. |
| Lock and lifecycle | "if the file version to which the rule applies has Object Lock enabled, then the deletion does not occur". | Rules can't break a lock. |
| Lifecycle timing | Applied once a day, at the next daily run after the days pass. Minimum one day. With 1 + 1, everything is gone within 72 hours. | 84 + 1 means about day 86. |
| Lifecycle rules | Set through the web console or Native API, not the S3 API. Up to 100 per bucket. Overlapping rules take the smallest value. An empty prefix can delete everything. `daysFromUploadingToHiding` "applies to all of the copies of the file, even the most current version". | Never use it on `objects/`. Never use an empty prefix. |

### Not found in the documentation

These are assumptions in the code or the fake store. Each needs a test on a scratch bucket before `--apply`.

| Question | Assumed | If wrong |
|---|---|---|
| **When deleted data physically leaves Backblaze's disks** | Unknown. Nothing found states it, and the Security page doesn't cover it. Ask Backblaze if the policy needs it. | The policy must say "deleted from our backups", not "erased". The copies are encrypted with a key Backblaze doesn't hold. |
| Does S3 delete by version id remove a hide marker? | Yes | Markers stay, and their names hold user ids. A lifecycle rule may clear them: the docs say a hide marker that is a file's oldest version is deleted regardless of age. |
| Does a locked delete fail with S3 code `AccessDenied`? | Yes (documented for the Native API) | The run stops with an error. Fails closed. |
| What does `get-object-legal-hold` return with no hold? | `OFF` or a "no configuration" error | Treated as unknown: nothing deleted, alarm raised. Fails closed. |
| Does `HeadObject` return metadata for a given old `VersionId`? | Yes | Treated as unknown: version kept, alarm raised. Fails closed. |
| Does a rule retry a deletion that a lock blocked? | Probably | Only affects the backstop. |
| Can a lifecycle rule hide a locked version? | Not stated | Only affects the backstop. |
| Do new rules apply to files already in the bucket? | Probably | The prune covers them regardless. |

### Needs a read-only check of the live buckets by the owner

The repo records intent, not live state. `docs/disaster-recovery.md` describes these settings, but nothing confirms them (U9). No credential was used for this work.

| Check | Where | Needed |
|---|---|---|
| Object Lock mode and default days, per bucket | `b2 bucket get <bucket>` or the console | Governance or compliance, 30 days. **Anything over 80 breaks the design.** |
| Lifecycle rules, per bucket | Same | `db/` 35 + 1, `monthly/` 365, `manifests/` 400, nothing on `objects/`, no empty prefix |
| Cloud Replication | Same | None. A replica would be another copy this design doesn't reach. |
| Key capabilities | `b2 key list --long` or the console | Backup keys: no `deleteFiles`, no `bypassGovernance` |
| Legal holds, and locks past 30 days | `b2 ls --long --versions --recursive b2://<bucket>` sample | None |
| Region | Bucket details | `us-east-005` per the drill record, while `offsite.py` defaults to `us-west-004` |
| Oldest version in each prefix | `b2 ls` as above | To size the first prune |

## Copies outside B2

The promise says "backup copies", so these count even though the code doesn't touch them. **Each needs an owner decision before step 9.**

- **Neon forensic branches** `production-out-of-band-2026-10-22` (`br-quiet-dust-b5dxh8dp`) and `production-out-of-band-2-2026-10-22` (`br-raspy-tooth-b5om6gel`). Confirmed to exist today. They are point-in-time copies of production with no expiry, kept until the owner says otherwise.
- **Neon history**, 7 days. Inside the limit, but a restore from it needs the replay.
- **Local files.** `~/.movemark-dr/backups` holds one archive, named as a dev backup, from 2026-10-22. Check any drill work directories and any copies from the 2026-10-26 production restore drill.
- **The Neon Object Storage history**, if any. Not checked.

## Rollout

Every step needs owner approval. Stop if any check fails.

| # | Change | Check | Rollback |
|---|---|---|---|
| 0 | Owner completes the read-only checks above and decides the 90/80/120 numbers, the shorter restore window, and the forensic branches | Results recorded here | None needed |
| 1 | On a scratch B2 bucket with Object Lock and a short lock, run the "not found" questions | Answers recorded here; code adjusted | Delete the scratch bucket once locks lapse |
| 2 | Migration 1060: dev, then production through the runner (`check` first) | Runner clean; one real account deletion on dev leaves a tombstone | `neon/rollback/1060_deletion_tombstones.down.sql`, shipped as the next numbered migration, after an export |
| 3 | Backup image: add `scripts/dr/deletion_log.py` to the Dockerfile `COPY`, and this line after `backup.py` in `run_scheduled.sh`: `python scripts/dr/deletion_log.py export --key-file "$work/backup.key" --dsn-env BACKUP_DATABASE_URL`. The change goes on the branch Railway builds. | First batch appears. Runs for 7 days. | Remove the line. Batches stay and age out under the lock. |
| 4 | Create two prune keys, one per bucket: `listFiles`, `readFiles`, `deleteFiles`, `readFileRetentions`, `readFileLegalHolds`. No `writeFiles`, no `bypassGovernance`. Create a separate Railway cron service, daily, running `retention.py prune` **dry run only**. | 7 clean dry runs; counts reviewed by a person | Delete the service and keys |
| 5 | Exit-code alerting on that service, and on the backup job | A forced refusal reaches a person | Remove the alert |
| 6 | Lifecycle rules, in this order: `manifests/` to 84 + 1, `monthly/` to 84 + 1, then `objects/` with `daysFromHidingToDeleting` 85 only. Leave `db/`. No `daysFromUploadingToHiding` on `objects/`. Add no rule for `deletion-log/`. | Read the rules back; run the dry run again | Put back the old values. Files already deleted don't return. |
| 7 | Add the replay steps to `docs/disaster-recovery.md` and run a production restore drill into a blank environment, with replay | `RESTORE_DRILL PASS`, `SERVICE_UNFENCED` | Runbook text only |
| 8 | First `--apply`, attended. Then turn on `--apply` in the daily service. | Exit 0, `still_listed_after_delete` 0, restore drill passes again | **Deletion can't be undone.** Turn off `--apply` to stop further deletion. |
| 9 | Read back every version: nothing past the limit, nothing unknown. Deal with the copies outside B2. | Evidence recorded here | None needed |
| 10 | Publish the policy text, update the website, the apps' deletion copy and `docs/disaster-recovery.md`, and close P0-1 and P0-2 | Text matches what step 9 proved | Revert the text |

Rollback of the policy text would come first if the prune ever stops for good: the 90-day claim must not outlive the job that makes it true.

**Files changed now but not live:** `restore.py` and `b2_drill.py` run only by hand and aren't in the backup image. `backup.py`, `offsite.py`, `run_scheduled.sh`, the Dockerfile and `railway.toml` are unchanged, so the scheduled job behaves exactly as before. `b2_drill.py` now needs 1060 on dev and a log export, and it wasn't run here because it needs dev object storage and the moto server.

## Privacy Policy text

**This becomes true at step 9, and not before.** It replaces the "no fixed expiry" statements in the summary, sections 10 and 11, and the sentence "We don't yet have an automatic step that deletes it again." It assumes the numbers above. Publish it only with the lawyer's review of the wider policy.

The sentence:

> When you delete your account, a rental, a photo or a document, we remove it from our live systems, and we delete its encrypted backup copies within 90 days; they can't be changed or removed for the first 30 of those days, and until they are deleted we use them only to recover from data loss.

Directly after it, because the sentence alone would overstate what a restore does:

> If we ever have to restore from a backup, we first delete again any account or rental you deleted, using a separate record that holds no name or email address and that we keep for 120 days. A single photo or document you deleted after that backup was made could return until the backup expires, and an account deleted in the few hours before a complete loss of our database could return until we delete it again.

Section 10 table rows, replacing the three backup rows:

| Information | How long it is kept |
|---|---|
| Database backups | Up to 90 days |
| Backup file list (encrypted) | Up to 90 days |
| Backup copies of photos, documents and reports | Up to 90 days after the live version is deleted or replaced |
| Record of deleted accounts and rentals (no name or email address) | 120 days, and until the next account deletion after that |

If the API write-through ships, drop the last clause of the second paragraph. If the owner picks other numbers, change them in `Policy`, in 1060 and here together.

## Test evidence

Run 2026-11-07. `movemark-api-py/.venv/bin/python -m pytest scripts/dr/tests neon/tests -q`.

| Suite | Result | Covers |
|---|---|---|
| `scripts/dr/tests/test_retention.py` | 44 passed | Fake B2 through the real `sync_evidence` and `push_db`: window timing, replaced and shared objects, locks, hide markers, every refusal, plus three simulated years (random deletions, prune outages of up to 8 days, lifecycle backstop) checking no copy passes 90 days and nothing current is lost |
| `scripts/dr/tests/test_deletion_log.py` | 20 passed | Chain tampering, gaps, heartbeats, a database rewound by a restore, file replay |
| `scripts/dr/tests/test_restore_replay_drill.py` | 21 passed | Local PostgreSQL 18 with the real `backup.py`, `offsite.py`, `restore.py`, `deletion_log.py`, `retention.py` (below) |
| `neon/tests` | 342 passed | Includes 46 new in `test_deletion_tombstones.py`: capture, access, expiry, rollback equals a build through 1050 |

**The drill.** Accounts A and B with rentals and files. Backup. Delete A and one rental of B. Export. Restore the backup from before the deletions, with its files. Result: A's identity, rows and files are gone, as is the rental, and B's rows and files are byte-identical. With no replay, `movemark_api` and `movemark_worker` can't log in, `authenticated` and `anonymous` are refused, and A is visibly back, which is why the fence exists. A tampered log, a missing batch and a log stopping before the backup each leave the fence up. Then, 85 simulated days on, a prune removes every version of A's files from the fake B2, and a restore from what remains still has all of B.

**On real Neon.** On a child of `dev` (`br-calm-scene-b5gdw024`, deleted afterwards): runner `check` found no drift (43 applied) and `apply` took 1060 cleanly as `neondb_owner`. An account deleted through the real functions left a tombstone with the Python hash. The fence closed all three logins and refused `authenticated` and `anonymous`, replay removed a seeded account and left another, and lifting restored the logins and the schema ACL exactly. Run by hand, not a committed script. The fence was tested at the role level, not through a real Data API request.

**Found by these tests, and fixed:** the fence first revoked only the two roles, which did nothing, because `PUBLIC` also holds USAGE on `public`; and `restore.py` failed to load the new module.

**Not run:** `b2_drill.py`, real B2 of any kind, and the API's own `delete_account_for_user`. The drill calls the same SQL functions in the same order.

A fake that passes proves the code follows this document's reading of Backblaze. It doesn't prove B2 behaves that way, which is what step 1 is for.

## Sources

- [Lifecycle rules](https://www.backblaze.com/docs/cloud-storage-lifecycle-rules)
- [Configure lifecycle rules](https://www.backblaze.com/docs/cloud-storage-configure-and-manage-lifecycle-rules)
- [Object Lock](https://www.backblaze.com/docs/cloud-storage-object-lock)
- [File versions](https://www.backblaze.com/docs/cloud-storage-file-versions)
- [S3-compatible bucket versions](https://www.backblaze.com/docs/cloud-storage-s3-compatible-api-bucket-versions.md)
- [Application key capabilities](https://www.backblaze.com/docs/cloud-storage-application-key-capabilities)
- [Security](https://www.backblaze.com/docs/cloud-storage-security.md)
- [b2_delete_file_version](https://www.backblaze.com/apidocs/b2-delete-file-version)
- [b2_list_file_versions](https://www.backblaze.com/apidocs/b2-list-file-versions)
- [b2_hide_file](https://www.backblaze.com/apidocs/b2-hide-file)
- [S3 Delete Object](https://www.backblaze.com/apidocs/s3-delete-object) (flagged stale on the page)
- [S3 List Object Versions](https://www.backblaze.com/apidocs/s3-list-object-versions)
- [S3 Get Object Retention](https://www.backblaze.com/apidocs/s3-get-object-retention)
