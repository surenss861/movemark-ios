# Android manual QA gate (first run)

Do **one** pass. Do not add CameraX, billing, or UI polish until this is green.

## Prerequisites

1. **Emulator or phone**
   - Android Studio → **Tools → Device Manager** → Create / **Start** a Pixel-style AVD (API 30+).
2. **Terminal check**

```bash
adb devices
```

Expected:

```text
emulator-5554    device
```

3. **Secrets** — `movemark-android/local.properties` has `SUPABASE_URL` and `SUPABASE_ANON_KEY` (copy from `local.properties.example`).

4. **Supabase** — For sign-up QA, disable “Confirm email” in Supabase Auth **or** use the confirm-email message and sign in after confirming.

---

## Install and launch

From repo root:

```bash
chmod +x scripts/android-device-qa.sh
./scripts/android-device-qa.sh
```

Or Android Studio: open `movemark-android` → **Run**.

---

## Proof loop (only flow to test first)

| Step | Action | Pass? |
|------|--------|-------|
| 1 | Welcome → **Start move-in proof** → Sign up (new email) | ☐ |
| 2 | Create rental (address required) | ☐ |
| 3 | **Vault** — rental name, `0 of 10 rooms ready`, Next: Kitchen | ☐ |
| 4 | **Rooms** — Kitchen shows needs photos | ☐ |
| 5 | Tap **Kitchen** → **Add photos** → pick **2** images | ☐ |
| 6 | **Save proof** → auto back to Rooms/Vault | ☐ |
| 7 | Vault/Rooms → **1 of 10 rooms ready**, Kitchen documented | ☐ |
| 8 | **Report** — can tap **Make report** (≥1 room documented) | ☐ |

### Rule (non-negotiable)

```text
0 photos  → NOT documented
1+ photos → documented
```

---

## Emulator tips

- **Photos:** Drag JPGs onto the emulator window, or use Extended Controls → **Camera** / **Gallery**.
- **Sign up:** Use a fresh email each run (`you+android1@test.com`).
- **Logcat:**

```bash
adb logcat | grep -iE 'MoveMark|Supabase|AndroidRuntime|FATAL'
```

---

## First failures (what to capture)

```text
flow:
screen:
expected:
actual:
logs:
screenshot:
build:
```

| Area | Symptom |
|------|---------|
| Auth | “Confirm your email” — sign in after confirm, or disable confirm in Supabase |
| Vault empty | Property created but rooms missing — check `rooms` insert / RLS |
| Upload | “Photos could not be uploaded” — `inspection-media` bucket + storage RLS |
| Counts stuck | Save OK but still `0 of 10` — hydration; check Logcat after save |
| Reports | Export error — `MOVE_MARK_API_BASE_URL` + bearer token |

Fix **one** issue → **one commit** → rerun from the step before failure.

---

## Not in scope yet

```text
CameraX
Play Billing / RevenueCat
Motion polish
Full UI redesign
```
