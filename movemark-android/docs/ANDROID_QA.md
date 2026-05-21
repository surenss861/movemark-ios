# MoveMark Android QA

Run from:

```bash
cd /Volumes/sss/movemark/movemork/movemark-android
./gradlew :app:assembleDebug
```

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
