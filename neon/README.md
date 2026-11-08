# MoveMark on Neon (recovery)

Database for the Neon recovery. See [[RECONSTRUCTION]] for every schema assumption and the gate results.

Apply order: `migrations/` sorted by filename. On Neon, **Auth must be enabled on the branch first**: 0300/0340 reference `neon_auth."user"`, which Neon Auth creates. Data API supplies `authenticated`, `anonymous` and `auth.user_id()`. Never apply `tests/neon_platform_shim.sql` to Neon.

Regenerate ported files after changing `supabase/migrations`: `python3 neon/port_migrations.py`

Run the gate (local Postgres): `movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests -q`

Legal gate: `1030`/`1040`/`1050` add the records and the Data API policies; all are inert until `legal_gate_settings.enforced` is true and documents are published. Rollback bodies are in `rollback/` (they ship as the next numbered migration, never pasted). `legal_gate_dev.py` seeds draft documents and flips the switch on dev or a child of dev only. See `docs/legal-gate/`.

Age attestation: `1055` adds the age-eligibility confirmation (owner decision D1): a four-argument `accept_legal_documents(..., p_age_attestation)` that refuses anything but `legal_gate_settings.age_requirement` (`age_13_qc_14`, or the `age_18` fallback). The three-argument function stays for build 20261107.1 while enforcement is off and refuses once it is on; with enforcement on, an acceptance counts only with the current attestation. Numbered below `1060` so production can take `1030`–`1055` from a checkout without `1060`.
