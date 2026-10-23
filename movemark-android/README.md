# MoveMark Android

Native **Kotlin + Jetpack Compose** client for MoveMark. Shares the production architecture of the iOS app (`movemork/`): Neon Auth for sign-in, the Neon Data API (PostgREST, under RLS with the user's token) for rows, and the MoveMark API (Railway) for files and reports.

## Location

```
movemork/movemark-android/
```

## MVP flows

- Welcome → email auth (Neon Auth)
- Create rental vault → default rooms
- Vault / Rooms tabs with **real** `photoCount > 0` documented logic
- Room proof → photo picker → MoveMark API upload ticket (immutable source + derivative + thumbnail) → evidence rows
- Report tab → Railway `POST /api/exports/move-in`
- Account → Privacy / Terms / sign out

## Setup

1. Open **`movemork/movemark-android`** in Android Studio (Ladybug or newer).
2. Copy `local.properties.example` → `local.properties`.
3. Set `NEON_AUTH_URL`, `NEON_DATA_API_URL` and `MOVEMARK_API_BASE_URL` for **debug** builds (a non-production
   Neon branch and a dev API; from an emulator the local dev API is `http://10.0.2.2:8787`). Release builds are
   hard-wired to production in `app/build.gradle.kts` and ignore these.
4. Sync Gradle and run on emulator or device (API 26+).

## Project structure

```
app/src/main/java/com/surensureshkumar/movemark/
  core/design/          MMTheme, buttons, cards, tab bar
  core/navigation/      NavHost + routes
  data/auth/            SessionManager
  data/property/        PropertyRepository, InspectionRepository, PropertyStore
  data/remote/          ExportApiClient (Railway)
  features/             welcome, auth, firstrun, vault, rooms, proof, reports, account
```

## Next (after MVP runs)

- CameraX in-app camera
- RevenueCat + Play Console products (`movemark_pro_monthly` / `movemark_pro_yearly`, entitlement `movemark_pro1`)
- Export list + share download URL
- First-run receipt UI polish

## Room proof rule

A room is **documented** only when it has at least one photo on file (`photoCount > 0`). Rows alone do not count.
