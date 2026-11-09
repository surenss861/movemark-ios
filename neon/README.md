# MoveMark on Neon (recovery)

Database for the Neon recovery. See [[RECONSTRUCTION]] for every schema assumption and the gate results.

Apply order: `migrations/` sorted by filename. On Neon, **Auth must be enabled on the branch first**: 0300/0340 reference `neon_auth."user"`, which Neon Auth creates. Data API supplies `authenticated`, `anonymous` and `auth.user_id()`. Never apply `tests/neon_platform_shim.sql` to Neon.

Regenerate ported files after changing `supabase/migrations`: `python3 neon/port_migrations.py`

Run the gate (local Postgres): `movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests -q`

Legal gate: `1030`/`1040`/`1050` add the records and the Data API policies; all are inert until `legal_gate_settings.enforced` is true and documents are published. Rollback bodies are in `rollback/` (they ship as the next numbered migration, never pasted). `legal_gate_dev.py` seeds draft documents and flips the switch on dev or a child of dev only. See `docs/legal-gate/`.

Age attestation: `1055` adds the age-eligibility confirmation (owner decision D1): a four-argument `accept_legal_documents(..., p_age_attestation)` that refuses anything but `legal_gate_settings.age_requirement` (`age_18`, the 18+ launch policy and default; `age_13_qc_14` stays allowed for a later change). Self-declared, not verified. The three-argument function stays for build 20261107.1 while enforcement is off and refuses once it is on; with enforcement on, an acceptance counts only with the current attestation. Numbered below `1060` so production can take `1030`–`1055` from a checkout without `1060`.

Quebec (temporary, until French versions exist): `1057` makes `bands_v2` the requirement: the age range plus "Do you live in Quebec?" for every age, through a six-argument `accept_legal_documents(..., p_age_band, p_lives_in_quebec)`. "Yes" is refused with `LEGAL_REGION_NOT_AVAILABLE` and nothing is written; "No" is stored as `legal_acceptances.residence = 'outside_quebec'`, the only value the column takes. The 3-, 4- and 5-argument calls can't accept under `bands_v2` (the 3-argument one even while enforcement is off), and `acceptance_required` stays true until a `bands_v2` acceptance exists. Self-declared; not location verification. Numbering: `1057` this, `1058` the documents publish, `1059` the one remaining rollback slot below `1060`.
