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

## Versioning

- `versionName` matches the iOS marketing version (currently **1.4.0**).
- `versionCode` is **YYYYMMDDNN**: the build date and a two-digit sequence for that day (`2026110201` is the
  first build of 2 Nov 2026). It sorts above every earlier code (the first uploads used 1) and stays below
  Play's 2,100,000,000 limit through 2099.
- Both live in `gradle.properties` (`movemarkVersionName`, `movemarkVersionCode`). Bump the code for every Play
  upload (Play rejects a code it has already seen); for a one-off build pass `-PmovemarkVersionCode=…`.
  The build fails on a code that isn't a real date plus 01–99, or a name that isn't `x.y.z`.

## Play internal-testing AAB

Prerequisites, in `movemark-android/local.properties` (gitignored, never committed or pasted anywhere):
- `MOVEMARK_UPLOAD_STORE_FILE`, `MOVEMARK_UPLOAD_STORE_PASSWORD`, `MOVEMARK_UPLOAD_KEY_ALIAS`,
  `MOVEMARK_UPLOAD_KEY_PASSWORD`: the Play upload key (keystore in `~/.movemark-android/`).
- `REVENUECAT_PUBLIC_KEY=goog_…`: the RevenueCat **Google Play** public SDK key. Optional for the very first
  upload (see below).
- `SENTRY_DSN=…`: the Android Sentry project's DSN. Empty means crash reporting is off.

Steps:
1. Bump `movemarkVersionCode` in `gradle.properties` (YYYYMMDDNN, see "Versioning").
2. Build:
   ```
   cd movemark-android
   export GRADLE_USER_HOME=/Volumes/sss/movemark/.gradle-home
   export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
   ./gradlew testDebugUnitTest lintDebug bundleRelease
   ```
   The release build refuses to run without the upload key, and refuses a missing, `appl_`, `sk_` or other
   non-`goog_` RevenueCat key. Release always targets production (Neon Auth, Data API, Railway API).
3. Check the output, `app/build/outputs/bundle/release/app-release.aab`: `jarsigner -verify` reports it verified,
   and the signer is "CN=MoveMark Upload, O=MoveMark".
4. Upload it by hand in Play Console → Testing → Internal testing. No Gradle task uploads anything.

First upload before billing exists: Play Console only lets you create in-app products once the app has an uploaded
build that includes the Billing library (this one does). If the `goog_` key isn't available yet, build the first
internal release with
`./gradlew bundleRelease -PmovemarkAllowNoBilling=true`
(the paywall then says plans are unavailable), upload it, then:
- create the one-time product **`report_pack`** (consumable) and the Pro subscriptions in Play Console;
- attach them in RevenueCat (entitlement `movemark_pro1` for Pro; `report_pack` grants credits through the API
  webhook);
- put the `goog_` key in `local.properties`, bump `movemarkVersionCode`, and build and upload a newer AAB.
