# MoveMark QA harness (Neon `dev` only)

Reproducible gates. Credentials are fetched from the Neon CLI into `~/.movemark-qa/dev` (mode 0700,
never committed); every script refuses production endpoints. Logs and run output stay in that folder.

| Script | What it does |
|---|---|
| `dev_env.sh` | `source` it: dev DSNs + dev Object Storage env, verified to be dev |
| `run_dev_api.sh [--no-worker]` | local MoveMark API on 127.0.0.1:8787 (+ worker) against dev; honours `API_DOCS=off` |
| `dev_zero_state.py [--count-only]` | purge QA leftovers through `delete_account_for_user`; print counts and `DEV_ZEROED` |
| `ios_lifecycle.sh [wait] [sim]` | the 17-step iOS lifecycle gate, serial, with pre-run zero check and post-run counts |

Schema changes never go through this folder: use `neon/migrate.py` (ledger, checksums, production guard).
Nothing in `neon/tests/` may ever run against a Neon branch.
