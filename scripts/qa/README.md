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

## Physical-device evidence gate (Neon dev only)

Needs the dev API on 127.0.0.1:8787 (`run_dev_api.sh` with `API_DOCS=off`), a temporary Cloudflare Quick Tunnel to it
whose URL is set only in the gitignored `Config/Secrets.xcconfig` (never committed), and the paired iPhone unlocked.

1. `scripts/qa/device_evidence_gate.sh` — resets the QA account, runs `DeviceEvidenceGateUITests/testDeviceEvidenceGate`
   (library photo + in-app camera photo + listing record + move-in report), copies `Documents/evidence-audit.log`.
2. `device_evidence_verify.py qa-neon-a@movemark.test ~/.movemark-qa/dev/device-audit.log <out>` — hash chains
   (platform bytes → row → storage checksum → download), metadata, report; requires one library and one camera row.
3. `testDeleteAccountThroughApp` on the device, then `dev_zero_state.py --count-only`.
4. Stop cloudflared, confirm the URL no longer serves, restore `Secrets.xcconfig`, stop the API.

## Physical-device partial-save test (Neon dev only)

Same setup as the evidence gate, plus `fault_proxy.py` on 127.0.0.1:8788 with the Quick Tunnel pointed at it.

1. `scripts/qa/device_partial_save.sh` — resets the QA account, arms one API outage (25 s) at the second
   photo's finalize, runs `testPartialSaveIsReportedAndRetried`: the warning must be on screen, the success
   receipt must not appear, and "Try again" after the outage must finish the save.
2. `device_partial_save_check.py qa-neon-a@movemark.test 2` — exactly two rows with distinct sources, every
   ticket consumed or abandoned, every stored object referenced.
3. Delete the account, `dev_zero_state.py --count-only`, stop cloudflared/proxy/API, restore `Secrets.xcconfig`.
