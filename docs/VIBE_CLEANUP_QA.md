# MoveMark — Vibe-coded cleanup QA

Use this after the reliability pass. Goal: a random renter can install, sign up, document one room, make a report, and manage subscription **without hitting something broken**.

**Completion audit (code vs device):** see [`VIBE_CLEANUP_COMPLETION.md`](VIBE_CLEANUP_COMPLETION.md).

Run on **TestFlight** (or Release archive) with production `appl_…` RevenueCat key.

---

## Flow 1 — New user

| Step | Expected |
|------|----------|
| Welcome → sign up | Lands in onboarding or first vault setup, not a confusing empty dashboard |
| Create vault / property | One property on Free; clear next step |
| Pick / add first room | Custom name validates empty; duplicate name shows friendly error |
| Capture proof (2+ photos) | Upload progress visible; save disabled while uploading; no duplicate saves on double-tap |
| Room progress | Room counts as documented only with photos; never “proof saved” with 0 photos |
| Progress / timeline | Vault timeline matches photo-based documented rule |

---

## Flow 2 — Returning user

| Step | Expected |
|------|----------|
| Sign in | Restores vault; no stale other-user data |
| Continue next room | Next room logic matches list + vault hero |
| Report tab | Status obvious: not ready / can make / queued / processing / ready / failed |
| Re-open app mid-export | Processing state still shown after refresh |

---

## Flow 3 — Subscription

| Step | Expected |
|------|----------|
| Account → Upgrade | Plans load (monthly + yearly) with price + duration; legal links open |
| Plans fail | “Plans didn’t load” + Try again + Continue on Free — **no infinite spinner** |
| Purchase | Loading on button; success overlay; Pro only when entitlement active |
| Restore (paywall + account) | UI updates immediately; clear message if none / error |
| Manage subscription (Pro) | Opens Apple subscriptions page |
| Account plan row | Shows Free or Pro Active — never “Pro” without entitlement |

---

## Flow 4 — Failure

| Step | Expected |
|------|----------|
| Airplane mode → save proof | Clear network message; retry on banner |
| Airplane mode → queue report | Clear error; no silent failure |
| Expired session (or revoke in Supabase) | Next API call → “Session expired” → returned to sign-in |
| RevenueCat offline | Sanitized plan error, not raw SDK strings |
| Duplicate export tap | Second request blocked while queued/processing |
| Failed export | Retry path; terminal failed state labeled |

---

## Flow 5 — Account & legal

| Step | Expected |
|------|----------|
| Privacy Policy | Opens in Safari |
| Terms of Use | Opens in Safari |
| Contact support | Opens URL or mailto |
| Account deletion link | Opens configured URL |
| Reset password | Success or error message on Account |
| Sign out | Full session clear; vault cleared locally |
| About disclaimer | States app is **not legal advice** |

---

## Capture template (when something fails)

```text
flow:
screen:
expected:
actual:
endpoint: (if API)
status:
screenshot:
build: (version + TestFlight #)
```

Fix **one** issue → **one commit** → re-run from the step before failure.

---

## Sprint mapping (done in code)

| Sprint | Items |
|--------|--------|
| **1 Launch blockers** | Paywall loading/error/restore/success; legal URLs; session expiry sign-out; restore error copy |
| **2 Proof hardening** | Documented = photos; export dedupe; append upload guard |
| **3 Code cleanup** | Removed unused tab bar V2 + 8 dead card components; `MMProofChecklistItem` extracted |
| **4 QA harness** | This doc + `MoveMarkReliabilityTests` |

---

## Related docs

- `docs/RELEASE_CHECKLIST.md` — ship gates
- `docs/app-review.md` — App Store Connect paste-in
- `docs/QA_TEST_RUN_ORDER.md` — full route order
