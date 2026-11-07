# MoveMark on Neon (recovery)

> **Canonical migration history (owner decision, 2026-11-07).** `movemork/neon/migrations/` is the only source of truth for Consumer schema changes: tables, columns, indexes, constraints, RLS, functions and triggers. No other migration history in the API, iOS or Android projects. `supabase/migrations/` is frozen history. MoveMark Business keeps its own separate history.
>
> Rules: test on `dev` first; production only through `migrate.py`, with explicit approval, a tested sequence, backup verification and a rollback plan; files are immutable once applied to production, so corrections are new forward migrations; the ledger `movemark_meta.schema_migrations` says what is really applied, not the presence of a file.


Database for the Neon recovery. See [[RECONSTRUCTION]] for every schema assumption and the gate results.

Apply order: `migrations/` sorted by filename. On Neon, **Auth must be enabled on the branch first**: 0300/0340 reference `neon_auth."user"`, which Neon Auth creates. Data API supplies `authenticated`, `anonymous` and `auth.user_id()`. Never apply `tests/neon_platform_shim.sql` to Neon.

Regenerate ported files after changing `supabase/migrations`: `python3 neon/port_migrations.py`

Run the gate (local Postgres): `movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests -q`

Legal gate: `1030`/`1040`/`1050` add the records and the Data API policies; all are inert until `legal_gate_settings.enforced` is true and documents are published. Rollback bodies are in `rollback/` (they ship as the next numbered migration, never pasted). `legal_gate_dev.py` seeds draft documents and flips the switch on dev or a child of dev only. See `docs/legal-gate/`.

Deletion tombstones: `1060` records deleted accounts and rentals as salted hashes. It is the capture point only: `scripts/dr/deletion_log.py` copies it outside the database and a restore replays it. Proposed, not on production. See `docs/backup-retention-design.md`.
