# Sprint 3, Item 15 — End-to-end QA

One full real-user journey to confirm the app works end-to-end without breaks.

**Status:** Script ready. **Item 15 is not complete until this path is run and signed off.** Execute in order, tick each step, then sign off pass/fail.

---

## Prerequisites

- Simulator or device with the app installed.
- Supabase project running (migrations applied, RLS enabled).
- Test account (or sign up during the run).

---

## QA path (run in order)

- [ ] **Sign up / sign in** — Create account or sign in; land on expected screen (onboarding or Vault).
- [ ] **Onboarding** — If shown, complete name; confirm flow continues.
- [ ] **Add property** — Open Add Property (sheet from empty Vault or toolbar); fill required fields; submit; confirm Vault shows the new property.
- [ ] **Confirm default rooms** — Open Walkthrough; confirm default rooms exist (e.g. Living Room, Bedroom, etc.).
- [ ] **Add custom room** — Add a room (e.g. "Office"); confirm it appears in the room list.
- [ ] **Save move-in evidence in multiple rooms** — Open at least two rooms; add photos, notes, tags, condition; save; confirm proof appears and Walkthrough/Vault counts update.
- [ ] **Upload lease / deposit receipt / listing screenshot** — In Vault Supporting documents, upload at least one of each type (or available types); confirm status shows as attached.
- [ ] **Create maintenance issue with photos** — Open Maintenance; create an issue with title, category, details, photos; save; confirm it appears in the list.
- [ ] **Add follow-up and resolve it** — Open the issue; add follow-up note; save; then mark resolved; confirm status and list update.
- [ ] **Complete move-out checklist items** — Open Move-out; tick several checklist items; confirm they persist (e.g. after navigating away and back).
- [ ] **Save move-out proof** — In Move-out, open at least one room; capture move-out proof (photos/notes); save; confirm it appears and move-out readiness reflects it.
- [ ] **Save dispute draft with all fields** — Open Dispute Builder; set type, title, amount, summary, move-out date, itemized toggle, charge date; select some evidence/documents; Save draft; confirm success.
- [ ] **Reopen and verify restore** — Leave Dispute Builder; reopen it; confirm draft restores (fields and evidence selections).
- [ ] **Export simple dispute PDF** — In Dispute Builder, tap Export simple PDF; confirm share sheet or export completes; no silent failure.
- [ ] **Generate formal packet** — Tap Generate formal packet; confirm share/open or export completes; no silent failure.
- [ ] **Verify Export History and sharing** — Open Exports (Export History); confirm move-in, move-out, and dispute exports appear; tap Verify where needed; Share each type; confirm no silent failure and status/errors are clear.
- [ ] **Sign out** — Account → Sign out; confirm app shows Welcome/Auth.
- [ ] **Relaunch signed out** — Force quit; reopen app; confirm still signed out (no Vault, no stale data).

---

## Sign-off

- **Date run:** _______________
- **Tester:** _______________
- **All steps passed:** ☐ Yes  ☐ No (note failures): _______________

Once all steps pass, Sprint 3 Item 15 can be marked complete.
