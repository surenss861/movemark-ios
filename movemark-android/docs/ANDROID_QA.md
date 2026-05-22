# MoveMark Android QA

**First device run:** follow [`ANDROID_MANUAL_QA_GATE.md`](ANDROID_MANUAL_QA_GATE.md) and `./scripts/android-device-qa.sh` from the `movemork` repo root.

Run from:

```bash
cd /Volumes/sss/movemark/movemork/movemark-android
./gradlew :app:assembleDebug
```

## End-to-end release candidate route

Run once on a device or emulator (mock billing: `BILLING_MODE=mock` in `local.properties`):

| Step | Screen | Action |
|------|--------|--------|
| 1 | Welcome | Proof hero card visible; **Start move-in proof** → sign up |
| 2 | Auth | Create account |
| 3 | Create rental | Name + address → vault |
| 4 | Rooms | First room → camera/gallery → **Save proof** |
| 5 | Receipt | Saved to vault; continue next room or vault |
| 6 | Report | Move-in report when ≥1 room documented |
| 7 | Account | Enable mock Pro / reset test subscription |
| 8 | Vault | Open move-out proof → capture → receipt |
| 9 | Report | Move-out report + dispute packet (Pro) |
| 10 | Account | Sign out → Welcome |

## P0 — Core proof loop

| # | Flow | Screen | Expected | Actual | Logs |
|---|------|--------|----------|--------|------|
| 1 | New user sign up | Auth | Account + profile created; navigates to Create rental | | |
| 2 | Create rental | Create property | Vault loads with 10 default rooms | | |
| 3 | Vault | Vault | Shows rental name, `X of Y rooms ready`, next room CTA | | |
| 4 | Rooms | Rooms | Kitchen = needs photos; counts honest | | |
| 5 | Room proof | Room proof | Pick 2 photos → Save → returns to previous tab | | |
| 6 | After save | Vault / Rooms | Kitchen documented (`photoCount > 0`); count +1 | | |
| 7 | Reports | Report | `Make report` enabled when ≥1 room documented | | |

## P2 — Move-out proof + report (mock Pro)

| # | Flow | Expected |
|---|------|----------|
| 12 | Vault → Open move-out proof | Pro/mock: room list opens; Free: paywall |
| 13 | Capture 2 move-out photos | Receipt “Move-out proof saved”; move-out count updates |
| 14 | Move-in counts | Move-in room/photo counts unchanged after move-out save |
| 15 | Reports → Move-out | No photos: “Capture move-out proof first.” + Open move-out proof |
| 16 | Make move-out report | With move-out photos: “Make move-out report” → building → ready |
| 17 | Duplicate tap | Second tap while building shows “already building” (no duplicate row) |
| 18 | Reopen app | Processing state still shown until ready or failed |
| 19 | Share | Ready: View/Share opens PDF chooser |
| 20 | Failed retry | Failed export: Retry report queues again |
| 21 | Free Reports CTA | Move-out report button → paywall “Move-out reports need Pro.” |

## P3 — Dispute packet (mock Pro)

| # | Flow | Expected |
|---|------|----------|
| 22 | No move-in proof | Dispute section: “Add room proof first.” → Continue room proof |
| 23 | With move-in proof | “Dispute packet can be made.” → Build dispute packet |
| 24 | Duplicate tap | Second build shows “already building” |
| 25 | Ready packet | View / Share packet opens PDF |
| 26 | Failed retry | Retry packet works after failure |
| 27 | Free user | Dispute CTA → paywall “Dispute tools need Pro.” |
| 28 | Legal copy | Shows “does not provide legal advice” (no “win/guaranteed” copy) |

## Rules (must not break)

- `photoCount == 0` → **not** documented
- `photoCount > 0` → documented
- No “proof saved” UI success without at least one uploaded photo

## P1 — Failure paths

| # | Case | Expected |
|---|------|----------|
| 8 | Save with no photos | Blocked with message |
| 9 | Airplane mode on save | Clear upload error; no fake documented room |
| 10 | Sign out | Returns to Welcome; vault cleared |
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
