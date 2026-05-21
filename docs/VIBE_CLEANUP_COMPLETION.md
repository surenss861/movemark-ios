# Vibe cleanup — completion status

Last audited: **2026-05-21** (codebase `main` @ `5a004fe` + Android `45c50eb`).

**Bottom line:** iOS **code + docs** for the cleanup pass are in place. **Launch is not “complete” until TestFlight manual QA and App Store Connect steps pass.** Android has the **MVP proof loop only** — not the full cleanup bar.

---

## Final ship gate (must be checked on TestFlight)

Run `docs/VIBE_CLEANUP_QA.md` on a **Release/TestFlight** build with production `appl_…` RevenueCat key.

| Gate | iOS code ready? | Verified on device? |
|------|-----------------|---------------------|
| TestFlight products load | Yes | ☐ You |
| Purchase works | Yes | ☐ You |
| Restore works | Yes | ☐ You |
| Terms / Privacy links work | Yes (Info.plist URLs) | ☐ You |
| New user documents one room | Yes | ☐ You |
| Report tab correct state | Yes | ☐ You |
| Account Free/Pro honest | Yes (`hasPro` = entitlement) | ☐ You |
| Sign out clears data | Yes (`AppRouter` + `PropertyStore.clear`) | ☐ You |
| No infinite spinners | Yes (paywall + export guards) | ☐ You |
| No raw SDK errors to user | Yes (sanitized plan/restore copy) | ☐ You |

**App Store Connect (outside repo):** Paid Apps Agreement, banking/tax, EULA in app description, IAP products ↔ RevenueCat — see `docs/app-review.md` and `docs/REVENUECAT_RELEASE.md`.

---

## Sprint 1 — Launch blockers (iOS)

| Item | Status | Where |
|------|--------|--------|
| Paywall loading / error / restore / success | Done | `ProPaywallView.swift`, `SubscriptionManager.swift` |
| Plans fail → “Plans didn’t load” + Try again + Continue on Free | Done | Paywall pricing card |
| `hasPro` only with entitlement `movemark_pro1` | Done | `SubscriptionManager` |
| Production `appl_…` key in Release (not `test_`) | Done | Build settings + runtime guard |
| Privacy / Terms / Support / Deletion links | Done | `Info.plist`, Account, Paywall, Auth |
| Not legal advice disclaimer | Done | `AccountView` About |
| Session expiry → sign-in | Done | `MoveMarkSessionExpiry`, `SessionManager`, `UserFacingDatabaseError` |
| Sign out clears vault | Done | `AppRouter.onChange`, `PropertyStore.clear` |
| Forgot password feedback | Done | Account + Auth |
| First-run not empty dashboard | Done | `FirstRunProofFlowView`, `needsOnboarding` |

---

## Sprint 2 — Proof hardening (iOS)

| Item | Status | Where |
|------|--------|--------|
| Documented = `photoCount > 0` | Done | `MMRoomProofMetrics` + tests |
| Save disabled while uploading | Done | `EvidenceCaptureView+Save`, append sheet |
| No double-save on tap | Done | `guard !isUploading` |
| JPEG compression | Done | Save pipeline ~0.82 quality |
| Camera denied → Settings message | Done | `EvidenceCaptureView` |
| Duplicate export while processing | Done | `hasActiveMoveInExportJob` |
| Report states (not ready / make / processing / ready / failed) | Done | `ExportHistoryView` |
| Share fetches fresh download URL | Done | `fetchDownloadURL` per share |
| Room name empty / duplicate validation | Done | `PropertyStore+Mutations` |
| Offline / API errors user-facing | Done | `MoveMarkFlowMessage`, `UserFacingDatabaseError` |

---

## Sprint 3 — Code cleanup (iOS)

| Item | Status |
|------|--------|
| Removed `MMProofTabBarV2` + 8 dead card components | Done (commit `5a004fe`) |
| `MMProofChecklistItem` extracted | Done |
| Design tokens centralized | Done (`MoveMarkTheme`) |
| No references to deleted components | Verified (grep clean) |

---

## Sprint 4 — QA harness

| Item | Status |
|------|--------|
| `docs/VIBE_CLEANUP_QA.md` | Done |
| `docs/RELEASE_CHECKLIST.md` | Done |
| `docs/app-review.md` | Done |
| `MoveMarkReliabilityTests` (room documented, session expiry, plans error, export labels) | Done |
| Crash analytics (Sentry/Firebase) | **Not in repo** — optional post-launch |

---

## Android (`movemark-android/`)

| Area | Status |
|------|--------|
| MVP proof loop (auth, vault, rooms, upload, reports request) | Done |
| Full vibe cleanup (paywall, CameraX denied UI, export list/share, etc.) | **Not done** — see `movemark-android/docs/ANDROID_QA.md` |

---

## What you should do next (in order)

1. **TestFlight** — Run all five flows in `docs/VIBE_CLEANUP_QA.md`; use the capture template for any failure.
2. **App Store Connect** — EULA in description, privacy field, IAP + agreements (`docs/app-review.md`).
3. **RevenueCat** — Confirm offering + `movemark_pro1` + product IDs (`docs/REVENUECAT_RELEASE.md`).
4. **Resubmit** only when every row in the ship gate table is checked on device.
5. **Android** — Separate track: proof-loop QA first; subscriptions later.

**Rule:** one bug → one fix → re-run from the step before failure (no redesign during QA).
