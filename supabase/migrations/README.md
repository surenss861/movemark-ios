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

## Apply one migration when `db push` history diverges

If `supabase db push` complains that remote migration versions are missing locally, you can still run a single file against the **linked** project:

```bash
npx supabase@latest db query --linked -f supabase/migrations/20260328000001_exports_requested_completed_at.sql --yes
```

Or: `./scripts/apply-exports-requested-completed-at.sh`

## If policies already exist

If you already have RLS or policies with the same names, drop them first or rename these. Supabase CLI will apply migrations only once (tracked in `supabase_migrations.schema_migrations`).

## issue_tags

`issue_tags` has SELECT only for `authenticated`. Inserts/updates/deletes (e.g. for seeding) should be done with the service role key or a separate migration using `SECURITY DEFINER` / admin path.
