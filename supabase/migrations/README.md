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
| `20260329000001_storage_buckets_and_policies.sql` | Creates Storage buckets (`inspection-media`, `maintenance-media`, `exports`, vault doc buckets, `documents`) + RLS on `storage.objects` (own `{user_id}/…` prefix) |
| `20260402000001_table_rls_evidence_docs_maintenance.sql` | Table RLS for `inspection_items`, `evidence_files`, `property_documents`, `maintenance_issues` (room evidence / lease / maintenance writes) |

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

Table RLS (after storage buckets), if room save still hits RLS errors:

```bash
npx supabase@latest db query --linked -f supabase/migrations/20260402000001_table_rls_evidence_docs_maintenance.sql --yes
```

Or paste the contents of that file into **Supabase Dashboard → SQL Editor → Run**.

The migration uses `to_regclass(...)` guards: if a table is missing (e.g. `inspection_items`), that section is skipped and Postgres emits a **NOTICE**. Room/move-out flows still need **`public.inspection_items`** to exist—if it never appears, pull schema from the canonical project or add the table before expecting those saves to work.

**Repair migration history (then use `db push` again):** only if you accept reconciling history—**back up first**. The CLI suggested marking remote-only versions as reverted:

```bash
npx supabase@latest migration repair --status reverted 20260306164304 20260306164335 20260310095112 20260311210715
npx supabase@latest db push --yes
```

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
