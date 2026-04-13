# MoveMark production migrations

Run these in order (by filename). Use Supabase Dashboard SQL editor or `supabase db push` if using Supabase CLI.

## Prerequisites

1. **Existing schema** – All tables from your current Supabase schema must already exist.
2. **Data compliance** – Before running:
   - Fix any rows where `inspection_type`, `status`, `dispute_type`, `document_type`, `export_type` etc. use values not in the new CHECK lists.
   - Ensure `evidence_files` rows have exactly one of `inspection_item_id` or `maintenance_issue_id` set (and fix `file_type` to one of `image`, `pdf`, `video`).
   - Ensure `dispute_evidence_links` rows have exactly one of `evidence_file_id`, `maintenance_issue_id`, or `property_document_id` set.
3. **Backup** – Take a snapshot/backup before applying.

## Order

| Migration | Purpose |
|-----------|---------|
| `20260312000001_schema_checks.sql` | CHECK constraints on enum-like text fields (inspections, maintenance_issues, property_documents, disputes, exports) |
| `20260312000002_exports_columns.sql` | Add `exports.status`, `metadata`, `error_message` and status check |
| `20260312000003_move_out_checklist_state_pk.sql` | Composite PK `(property_id, user_id)` on move_out_checklist_state |
| `20260312000004_dispute_evidence_links_check.sql` | Exactly-one-reference check on dispute_evidence_links |
| `20260312000005_evidence_files_checks.sql` | Exactly-one-parent + file_type check on evidence_files |
| `20260312000006_rls_enable.sql` | Enable RLS on all tables |
| `20260312000007_rls_policies_direct.sql` | RLS policies for tables with direct `user_id` |
| `20260312000008_rls_policies_indirect.sql` | RLS policies for rooms, inspection_items, evidence_files, issue_tags, inspection_item_tags, dispute_evidence_links |
| `20260328000001_exports_requested_completed_at.sql` | Adds `exports.requested_at` and `exports.completed_at` (idempotent) |
| `20260329000001_storage_buckets_and_policies.sql` | Creates Storage buckets + RLS on `storage.objects` — first path segment matches `auth.uid()` **case-insensitively** (`lower(...)`, for Swift UUID strings). |
| `20260329100000_storage_policies_uuid_case_insensitive.sql` | **Repair only:** same policy shape for projects that already applied an older `20260329000001` without `lower()`. Idempotent if policies already match. |
| `20260402000001_table_rls_evidence_docs_maintenance.sql` | Targeted table RLS (guarded if tables missing); prefer `20260402000003` for full app hardening |
| `20260402000003_full_app_rls_hardening.sql` | Full RLS for user-owned paths; **skips** any table that does not exist (`to_regclass` + `NOTICE`). Safe on empty DBs — but the app still needs the real schema on the linked project |
| `20260402000004_app_query_indexes.sql` | Same guard pattern: creates indexes only when each target table exists |

### `supabase db query` missing or `unknown flag: --linked`

Older global CLI builds (for example **v2.48.x**) only expose `supabase db` subcommands like `diff`, `dump`, `lint`, `pull`, `push`, `reset`, `start` — there is **no** `query`, so `--linked` fails. Use one of:

| Approach | Notes |
|----------|--------|
| **`npx supabase@latest db query --linked -f … --yes`** | Matches the repo scripts; does not rely on your global `supabase` version. |
| **Upgrade global CLI** | e.g. Homebrew: `brew upgrade supabase` until `supabase db query --help` works. |
| **Dashboard → SQL Editor** | Paste the migration file and run. |
| **`psql` + URI** | From **Project Settings → Database**, use the connection string: `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/….sql` (or set `DATABASE_URL` and run `./scripts/apply-*.sh` — see script headers). |

**Quiet output:** `npx … db query --linked` often prints only `Initialising login role…` and then nothing—DDL usually returns no rows. Exit code **0** means the file ran. The `./scripts/apply-*.sh` helpers print an explicit `OK: applied …` line after a successful run.

## When `db push` says “Remote migration versions not found in local migrations directory”

The linked database’s `supabase_migrations.schema_migrations` lists versions (e.g. `20260306164304`, `20260306164335`, …) that **are not** files in this repo. The CLI refuses to `db push` until local and remote history agree.

**Unblock uploads (storage) without fixing history:** run the storage migration SQL against the linked project (does not rely on `db push`):

```bash
cd movemork
./scripts/apply-storage-buckets-and-policies.sh
```

Or:

```bash
npx supabase@latest db query --linked -f supabase/migrations/20260329000001_storage_buckets_and_policies.sql --yes
```

Full table RLS (recommended after storage buckets):

```bash
npx supabase@latest db query --linked -f supabase/migrations/20260402000003_full_app_rls_hardening.sql --yes
npx supabase@latest db query --linked -f supabase/migrations/20260402000004_app_query_indexes.sql --yes
```

Older partial migration (skips missing tables via `to_regclass`):

```bash
npx supabase@latest db query --linked -f supabase/migrations/20260402000001_table_rls_evidence_docs_maintenance.sql --yes
```

Or paste SQL into **Supabase Dashboard → SQL Editor → Run**.

**If every table was skipped** (only `NOTICE movemark rls: skipped public.properties…` in the logs): your database has **no MoveMark tables**. Run SQL against the **same** Supabase project as the app (`supabase link` → pick that project’s ref), or restore schema first (`db pull` from production, or your original schema migration). RLS migrations do not create `properties` or other tables.

**Repair migration history (then use `db push` again):** only if you accept reconciling history—**back up first**. The CLI suggested marking remote-only versions as reverted:

```bash
# From repo root, linked to the right project: `supabase link`
supabase migration repair --status reverted 20260306164304 20260306164335 20260310095112 20260311210715
supabase db push
```

That **removes the four remote-only version stamps** so the CLI no longer expects missing files. It does **not** roll back schema by itself—it only fixes the migration history table.

**If `supabase db pull` then prints a long list of `migration repair --status applied …`:** the remote DB is missing “applied” records for migrations whose SQL you already ran (e.g. via Dashboard). Only run those `applied` lines if you are sure that migration’s SQL is **already** on the database; otherwise use `db push` to apply pending files normally after the `reverted` step.

If the remote schema was built outside this repo, prefer **`supabase db pull`** (or re-baseline migrations) so local files match production; see [Supabase migration docs](https://supabase.com/docs/guides/cli/managing-environments).

## Apply one migration when `db push` history diverges

If `supabase db push` complains that remote migration versions are missing locally, you can still run a single file against the **linked** project:

```bash
npx supabase@latest db query --linked -f supabase/migrations/20260328000001_exports_requested_completed_at.sql --yes
```

Same pattern for storage:

```bash
npx supabase@latest db query --linked -f supabase/migrations/20260329000001_storage_buckets_and_policies.sql --yes
```

Or: `./scripts/apply-exports-requested-completed-at.sh` · `./scripts/apply-storage-buckets-and-policies.sh`

## If policies already exist

If you already have RLS or policies with the same names, drop them first or rename these. Supabase CLI will apply migrations only once (tracked in `supabase_migrations.schema_migrations`).

## issue_tags

`issue_tags` has SELECT only for `authenticated`. Inserts/updates/deletes (e.g. for seeding) should be done with the service role key or a separate migration using `SECURITY DEFINER` / admin path.
