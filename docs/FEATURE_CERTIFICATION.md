# MoveMark — Product feature certification (manual)

**Purpose:** Treat MoveMark as a product, not a demo. Run flows **in the order below**. **Stop at the first failure**; record **Flow**, **Expected**, **Actual**, and **Repro steps** in `FEATURE_CERT_TRACKER.csv`; fix **one** path; re-run **from that step** (not from scratch unless needed).

**Not in scope for this pass:** Paywall / monetization polish.

**Source-of-truth detail (use these for step-by-step scripts):**

| Doc | Use for |
|-----|---------|
| [QA_TEST_RUN_ORDER.md](./QA_TEST_RUN_ORDER.md) | Phase A–D sequence, routes, sign-off |
| [SMOKE_TEST_CHECKLIST.md](./SMOKE_TEST_CHECKLIST.md) | Property switch, docs lifecycle, room queue, readiness pulses, rapid nav, storage edge cases |
| [HARDENING_QA.md](./HARDENING_QA.md) | E2E slice checklist and hardening by area |
| [E2E_QA.md](./E2E_QA.md) | Full signed-in journey (Sprint 3 Item 15) |
| [SECURITY_QA.md](./SECURITY_QA.md) | Two-account isolation (Sprint 3 Item 13) |

**Tracker:** Fill [FEATURE_CERT_TRACKER.csv](./FEATURE_CERT_TRACKER.csv) (columns: Flow, Expected, Actual, Repro steps). Leave Actual/Repro empty until a step fails; then fill only that row and fix before continuing.

**Exports / API:** Backend `GET /api/exports` returning 200 is assumed; Phase 8 validates **full UX** (rows, share, empty state), not HTTP status alone.

---

## Recommended order for a single day (fast path)

Run these **Flow IDs** first if time is short; they match the brutal sweep spine:

`P1.*` → `P2.1`–`P2.2` → `P3.*` (core evidence) → `P4.*` → `P5.*` → `P6.*` → `P7.*` → `P8.*` → `P9.*`

---

## Phase 1 — Auth + session + account

**Why first:** Flaky session invalidates every later test. Aligns with `QA_TEST_RUN_ORDER` Phase A items 1–5, 17; `HARDENING_QA` Auth/session; `E2E_QA` sign-in/onboarding.

| Flow ID | What to verify |
|---------|----------------|
| P1.1 | Cold launch **signed out** — Welcome, no Vault/tabs leak |
| P1.2 | Sign in completes; lands onboarding (if new) or signed-in root |
| P1.3 | Onboarding **name** flow completes without stuck loading |
| P1.4 | Force quit while signed in; relaunch — still signed in |
| P1.5 | Sign out — Welcome/Auth |
| P1.6 | Force quit signed out; relaunch — still signed out; no stale property |
| P1.7 | **Account** tab loads (name, email, version, sign out) |
| P1.8 | **Edit name** saves without crash; UI reflects change |
| P1.9 | Account **refresh** (pull or equivalent) works |
| P1.10 | **Legal** links open in browser / expected target |

---

## Phase 2 — Property / vault core

**Why:** Backbone of signed-in shell (Vaults → Property Vault → drill-ins). Cross-ref: `SMOKE_TEST_CHECKLIST` Passes 1–2; `QA_TEST_RUN_ORDER` Phase A 6–9, Phase B 20–22.

| Flow ID | What to verify |
|---------|----------------|
| P2.1 | **Create** property; sheet dismisses; property appears in Vaults |
| P2.2 | **Edit** property; changes persist in list and vault |
| P2.3 | Property visible in **Vaults** (no duplicate headings/cards) |
| P2.4 | **Open** vault — Proof vault, summary, action tiles |
| P2.5 | **Back** to Vaults list |
| P2.6 | **Switch** between multiple properties; featured/current correct |
| P2.7 | **No stale data** — rooms/docs/readiness match selected property |
| P2.8 | **Hero/readiness** match property; no wrong-property UI |

---

## Phase 3 — Rooms + evidence capture

**Why:** Core product value. Cross-ref: `HARDENING_QA` Room evidence; `QA_TEST_RUN_ORDER` Phase B 22–24; `SMOKE_TEST_CHECKLIST` Pass 4 (10–12), Pass 8 (20).

| Flow ID | What to verify |
|---------|----------------|
| P3.1 | **Default rooms** exist in Walkthrough |
| P3.2 | **Add custom room**; appears in list |
| P3.3 | **Room detail** opens from Walkthrough |
| P3.4 | **Photos** capture/add |
| P3.5 | **Notes / tags / condition** save |
| P3.6 | Return to vault/walkthrough — **counts** update |
| P3.7 | Reopen room — **persistence** |
| P3.8 | **Delete or modify** evidence; summary stays correct |
| P3.9 | **Move-in vs move-out** evidence separation (move-out mode saves to move-out evidence) |

---

## Phase 4 — Supporting documents

**Why:** Feeds readiness, export, dispute. Cross-ref: `SMOKE_TEST_CHECKLIST` Pass 3 (5–9), Pass 8 (19); `HARDENING_QA` Supporting documents; `QA_TEST_RUN_ORDER` Phase B 25.

| Flow ID | What to verify |
|---------|----------------|
| P4.1 | **Upload lease** — Missing → Uploaded |
| P4.2 | **Upload deposit receipt** |
| P4.3 | **Upload listing screenshot** |
| P4.4 | **Preview** correct file; no wrong bucket/stale URL |
| P4.5 | **Replace** doc — preview shows new file; no duplicate rows |
| P4.6 | **Delete** doc — row Missing; counts/readiness/export state consistent |
| P4.7 | **Counts/status** on vault summary correct |
| P4.8 | **No stale preview** after replace/delete |
| P4.9 | **No duplicate rows** in UI or apparent DB duplicates |

---

## Phase 5 — Maintenance

**Why:** Real feature area; dispute evidence quality. Cross-ref: `SMOKE_TEST_CHECKLIST` Pass 6 (15–16); `HARDENING_QA` Maintenance; `QA_TEST_RUN_ORDER` Phase B 26.

| Flow ID | What to verify |
|---------|----------------|
| P5.1 | **Create** maintenance issue |
| P5.2 | **Open** issue detail |
| P5.3 | **Add follow-up** |
| P5.4 | **Attach proof/photos** if supported |
| P5.5 | **Mark resolved**; list/detail update |
| P5.6 | **Vault summaries** (issue count, readiness) update |

---

## Phase 6 — Move-out

**Why:** High “looks done, breaks under use” risk. Cross-ref: `HARDENING_QA` Move-out; `QA_TEST_RUN_ORDER` Phase B 27; `E2E_QA` move-out steps.

| Flow ID | What to verify |
|---------|----------------|
| P6.1 | **Open** move-out flow |
| P6.2 | **Checklist** items complete; persist after leave/return |
| P6.3 | **Move-out proof** for ≥1 room saves |
| P6.4 | **Persistence** after navigate away and back |
| P6.5 | **Readiness/summary** reflects move-out state |
| P6.6 | **Move-out export** path if exposed in UI |

---

## Phase 7 — Dispute builder

**Why:** Proof-to-case leverage. Cross-ref: `HARDENING_QA` Dispute Builder + formal packet; `QA_TEST_RUN_ORDER` Phase B 28–31; `E2E_QA` dispute/export steps.

| Flow ID | What to verify |
|---------|----------------|
| P7.1 | **Create** dispute draft |
| P7.2 | **Fill** main fields (incl. move-out date, itemized, charge date per `HARDENING_QA`) |
| P7.3 | **Save** draft — success feedback |
| P7.4 | Leave and **reopen** — **full restore** (fields + selections) |
| P7.5 | **Simple PDF** generates; share/export no silent failure |
| P7.6 | **Formal packet** generates; field parity with simple path |
| P7.7 | **Evidence/document selections** persist across save/reopen |

---

## Phase 8 — Exports history + sharing

**Why:** Validate full UX now that API is healthy. Cross-ref: `HARDENING_QA` Export History; `QA_TEST_RUN_ORDER` Phase A 16, Phase B 32.

| Flow ID | What to verify |
|---------|----------------|
| P8.1 | **Export rows** appear for completed actions |
| P8.2 | **List loads** from app backend (e.g. Railway) without stuck error |
| P8.3 | **Move-in** export row appears where expected |
| P8.4 | **Simple / formal dispute** outputs appear where expected |
| P8.5 | **Share/download** works per export type |
| P8.6 | **Empty state** sane when no exports |
| P8.7 | **No stale error banner** after successful load |

---

## Phase 9 — Multi-account / security isolation

**Why:** Stateful SwiftUI + sign-out bugs hide here. Cross-ref: `QA_TEST_RUN_ORDER` Phase C; **`SECURITY_QA.md` full script** (Phases 1–6).

| Flow ID | What to verify |
|---------|----------------|
| P9.1 | User **A** creates real data (property, evidence, docs, exports) |
| P9.2 | Sign out A; sign in **B** — **no A data** on Vaults/Exports/Account |
| P9.3 | **B** creates own data; only B visible |
| P9.4 | Sign out B; sign in **A** — **no B bleed** |
| P9.5 | **Exports/documents/property** state clears correctly on account switch |

---

## After primary phases — Smoke cross-cuts (optional second pass)

When Phases 1–9 pass, run **`SMOKE_TEST_CHECKLIST.md`** in its **Order to run** sections for pulses, rapid navigation, and replace→delete storage edges (items 17–20). Stop/fill tracker the same way.

---

## Sign-off

- **Phases 1–9 completed without blocker:** ☐ Yes ☐ No — date: __________ — tester: __________
- **SMOKE cross-cuts (optional):** ☐ N/A ☐ Pass ☐ Fail — date: __________

**Rule:** Do not treat the app as “certified” until failed rows in `FEATURE_CERT_TRACKER.csv` are cleared and the failing steps are re-run successfully.
