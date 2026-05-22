# MoveMark Android QA

**First device run:** follow [`ANDROID_MANUAL_QA_GATE.md`](ANDROID_MANUAL_QA_GATE.md) and `./scripts/android-device-qa.sh` from the `movemork` repo root.

Run from:

```bash
cd /Volumes/sss/movemark/movemork/movemark-android
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleDebug
```

## Final RC route (run once on device/emulator)

Use `BILLING_MODE=mock` in `movemark-android/local.properties` for local Pro QA.

| Step | Screen | Action | Pass criteria |
|------|--------|--------|---------------|
| 1 | Welcome | Proof hero visible; **Start move-in proof** | Not generic login shell |
| 2 | Auth | Sign up | Loading on button; friendly errors only |
| 3 | Create rental | Fill name + address → **Create rental** | Lands in Vault with default rooms |
| 4 | Rooms | Open next room (e.g. Kitchen) | Status honest: needs photos |
| 5 | Room proof | **Take photos** or gallery → add 2 photos | Save states: Preparing / Uploading X of Y |
| 6 | Upload | **Save proof** completes | No fake success with 0 photos |
| 7 | Receipt | Saved to vault pulse/check | Continue next room or vault |
| 8 | Vault | Progress updates | `X of Y rooms ready` increments |
| 9 | Reports | **Make move-in report** (≥1 room documented) | Building → View/Share when truly ready |
| 10 | Account | Enable mock Pro / reset test subscription | Test mode only in mock billing |
| 11 | Vault | **Move-out proof** → capture room | Pro gated when Free |
| 12 | Reports | **Make move-out report** | Requires move-out photos |
| 13 | Reports | **Build dispute packet** | Requires move-in proof |
| 14 | Account | Privacy/Terms/Support links; reset password | Browser/mailto opens |
| 15 | Account | **Sign out** | Returns to Welcome; vault cleared |

### RC pass criteria (all flows)

- No crashes
- No stuck loading (every spinner has context or clears on failure)
- No raw Supabase/Ktor/RevenueCat/API strings in UI
- No fake “ready” report states
- No content hidden under tab bar
- `photoCount == 0` never counts as documented
- Free user cannot access Pro-only move-out/dispute without paywall

## P0 — Core proof loop

| # | Flow | Screen | Expected | Actual | Logs |
|---|------|--------|----------|--------|------|
| 1 | New user sign up | Auth | Account + profile created; navigates to Create rental | | |
| 2 | Create rental | Create property | Vault loads with 10 default rooms | | |
| 3 | Vault | Vault | Shows rental name, `X of Y rooms ready`, next room CTA | | |
| 4 | Rooms | Rooms | Kitchen = needs photos; counts honest | | |
| 5 | Room proof | Room proof | Pick 2 photos → Save → receipt | | |
| 6 | After save | Vault / Rooms | Kitchen documented (`photoCount > 0`); count +1 | | |
| 7 | Reports | Report | `Make report` enabled when ≥1 room documented | | |

## P2 — Move-out proof + report (mock Pro)

| # | Flow | Expected |
|---|------|----------|
| 12 | Vault → Open move-out proof | Pro/mock: room list opens; Free: paywall |
| 13 | Capture 2 move-out photos | Receipt “Move-out proof saved”; move-out count updates |
| 14 | Move-in counts | Move-in room/photo counts unchanged after move-out save |
| 15 | Reports → Move-out | No photos: “Capture move-out proof first” |
| 16 | Make move-out report | With move-out photos: building → ready → share |
| 17 | Duplicate tap | Second tap: “already building” (no duplicate job) |
| 18 | Reopen app | Processing state persists until ready/failed |
| 19 | Share | Ready: View/Share opens PDF chooser |
| 20 | Failed retry | Failed export: Retry works |
| 21 | Free Reports CTA | Move-out report → paywall |

## P3 — Dispute packet (mock Pro)

| # | Flow | Expected |
|---|------|----------|
| 22 | No move-in proof | “Add room proof first” → Continue room proof |
| 23 | With move-in proof | Build dispute packet → building → share |
| 24 | Duplicate tap | Second build: “already building” |
| 25 | Ready packet | View / Share opens PDF |
| 26 | Failed retry | Retry packet works |
| 27 | Free user | Dispute CTA → paywall |
| 28 | Legal copy | “does not provide legal advice” on Reports |

## Rules (must not break)

- `photoCount == 0` → **not** documented
- `photoCount > 0` → documented
- No “proof saved” UI success without at least one uploaded photo
- Back during upload → confirmation dialog
- Back after receipt → does not re-upload

## P1 — Failure paths

| # | Case | Expected |
|---|------|----------|
| 8 | Save with no photos | Blocked with message |
| 9 | Airplane mode on save | “Photos couldn't upload…” + Retry upload |
| 10 | Sign out | Welcome; vault cleared |
| 11 | Account links | Privacy + Terms open in browser |

## Capture template

```text
flow:
screen:
expected:
actual:
logs:
screenshot:
commit:
```

Fix **one issue → one commit → rerun from step before failure**.
