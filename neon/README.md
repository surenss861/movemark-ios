# MoveMark on Neon (recovery)

Database for the Neon recovery. See [[RECONSTRUCTION]] for every schema assumption and the gate results.

Apply order: `migrations/` sorted by filename. On Neon, **Auth must be enabled on the branch first**: 0300/0340 reference `neon_auth."user"`, which Neon Auth creates. Data API supplies `authenticated`, `anonymous` and `auth.user_id()`. Never apply `tests/neon_platform_shim.sql` to Neon.

Regenerate ported files after changing `supabase/migrations`: `python3 neon/port_migrations.py`

Run the gate (local Postgres): `movemark-api-py/.venv/bin/python -m pytest movemork/neon/tests -q`
