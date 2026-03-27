# MoveMark — QA test run order

**One executable sequence.** Run in order. Stop at first failure; fix; re-run from that step. Sign off each phase before moving to the next.

Current app shape: **signed-in root = bottom nav (Vaults | Exports | Account)**. Vaults tab = property list; tap property → Property Vault (Proof vault); from there: Walkthrough, Maintenance, Move-out, Dispute builder, Exports.

---

## Phase A — Route & flow (no data yet)

**Goal:** Every route opens and back/sheet behavior is correct. No dead buttons, no wrong screen.

1. [ ] **Launch signed out** — App shows Welcome (no Vault, no tabs).
2. [ ] **Welcome → Auth** — Tap sign in / create account; auth screen appears.
3. [ ] **Sign in** — Complete sign in; land on onboarding (if new) or signed-in flow.
4. [ ] **Onboarding** — If shown: enter name, continue; land in signed-in flow.
5. [ ] **Signed-in root** — Bottom nav visible: **Vaults** | **Exports** | **Account**. Default tab = Vaults.
6. [ ] **Vaults tab — empty** — Vaults shows “No property yet” (or empty list); **MoveMark** / **Vaults** header; Add property via toolbar + (or empty-state CTA).
7. [ ] **Add property sheet** — Tap Add property; sheet opens; Close dismisses; no crash.
8. [ ] **Create one property** — Fill required fields; submit; sheet dismisses; Vaults shows one property (featured card or list). No duplicate “Vaults” heading.
9. [ ] **Tap property** — Tap the property card; push to **Property Vault** (Proof vault header, vault summary, action tiles). Back returns to Vaults list.
10. [ ] **Property Vault → Walkthrough** — Tap Walkthrough tile; push to Walkthrough (header “Build your move-in record…”). Back returns to Property Vault.
11. [ ] **Walkthrough → Room detail** — Tap a room; push to Room Detail (evidence capture). Back returns to Walkthrough.
12. [ ] **Property Vault → Maintenance** — From Property Vault, tap Maintenance; push to Maintenance log. Back works.
13. [ ] **Property Vault → Move-out** — Tap Move-out tile; push to Move-out. Back works.
14. [ ] **Property Vault → Dispute builder** — Tap Dispute builder tile; push to Dispute Builder. Back works.
15. [ ] **Property Vault → Exports** — Tap Exports tile; push to Export History (or Exports tab content). Back works.
16. [ ] **Bottom tab Exports** — Switch to Exports tab; header “MoveMark” / “Exports” / “Reports and packets…”. No crash when no exports.
17. [ ] **Bottom tab Account** — Switch to Account tab; Account screen (name, email, version, sign out). Back not needed (tab root).
18. [ ] **Maintenance → Issue detail** — From Maintenance, tap an issue (if any) or add one then tap; push to Issue detail. Back works.
19. [ ] **UI consistency** — No duplicate nav bars; sheets have Close, not back; push screens have inline title and back; tab bar visible where expected (hidden on Room Detail / Dispute Builder per design).

**Checkpoint:** All routes open and close correctly. Then run Phase B.

---

## Phase B — End-to-end data flow (one property, one user)

**Goal:** One full proof trail: property → rooms → evidence → docs → maintenance → move-out → dispute → exports. State and counts stay correct.

20. [ ] **Add property** — Create one property; land on Vaults with that property.
21. [ ] **Open Property Vault** — Tap property; see Proof vault header, summary card (rooms/issues/docs/deposit), action tiles.
22. [ ] **Default rooms** — In Walkthrough, confirm default rooms exist (e.g. Living Room, Bedroom).
23. [ ] **Add custom room** — Add room (e.g. “Office”); it appears in list; “Add room” in toolbar or sheet.
24. [ ] **Save move-in evidence (2+ rooms)** — Open two rooms; add photos, notes, tags, condition; save each. Proof appears; Walkthrough and Property Vault summary counts update.
25. [ ] **Supporting documents** — In Property Vault, upload at least one doc (lease, deposit, or listing); status shows attached; preview/replace/delete if implemented.
26. [ ] **Maintenance** — Create one issue (title, category, details, optional photos); save. It appears in list; open detail; add follow-up; mark resolved. List and detail update.
27. [ ] **Move-out** — Open Move-out; tick checklist items; confirm persistence (navigate away and back). Capture move-out proof for at least one room; confirm readiness/counts update.
28. [ ] **Dispute draft** — Open Dispute Builder; set type, title, amount, summary, move-out date, itemized, charge date; select some evidence/documents; Save draft; confirm success.
29. [ ] **Draft restore** — Leave Dispute Builder; reopen; draft restores (fields and evidence selections).
30. [ ] **Export simple PDF** — In Dispute Builder, Export simple PDF; share sheet or export completes; no silent failure.
31. [ ] **Generate formal packet** — Generate formal packet; share/open or export completes; no silent failure.
32. [ ] **Export History** — Open Exports (tab or from Property Vault); move-in, move-out, dispute exports appear; Verify and Share work; status labels clear (Ready to share / problem states).
33. [ ] **Sign out** — Account tab → Sign out; app shows Welcome/Auth.
34. [ ] **Relaunch signed out** — Force quit; reopen; still signed out (Welcome, no Vault, no stale data).

**Checkpoint:** Full journey works; state and exports are coherent. Then run Phase C.

---

## Phase C — Security verification (two accounts)

**Goal:** User A never sees User B data. Sign out and sign in as B leaves no A data on screen. Use `docs/SECURITY_QA.md` for full script; below is the minimal run order.

35. [ ] **Account A** — Sign in as A; create property, rooms, evidence, doc, maintenance, move-out, dispute, export (per SECURITY_QA Phase 1). Checkpoint: A has full data.
36. [ ] **Sign out A** — Sign out; confirm Welcome/Auth.
37. [ ] **Sign in B** — Sign in as B. Vaults: no A property (empty or B’s list only). If B has no property, see “No property yet,” not A’s property.
38. [ ] **B creates own data** — B adds property; confirm only B’s property shown. B’s data only everywhere (Walkthrough, Maintenance, Exports).
39. [ ] **Signed URLs / storage** — As B, try to open or share an export that belonged to A (if you have a stored link); must fail or show nothing. No A data in Exports tab for B.
40. [ ] **Sign back to A** — Sign out B; sign in A. A sees only A’s property and data. No B data.
41. [ ] **Property switch (A)** — If A has multiple properties, switch via list; only A’s properties; selecting one shows correct vault and counts.

**Checkpoint:** Isolation and sign-out/switch behavior confirmed. Sign off SECURITY_QA.md and E2E_QA.md as needed.

---

## Phase D — Visual & state sanity (after A–C pass)

**Goal:** No layout breaks, no orphaned loading, no wrong copy. Quick pass.

42. [ ] **Long names** — Property title or address very long; header and cards wrap or truncate without breaking layout.
43. [ ] **Tab bar** — Visible on Vaults list, Property Vault, Exports, Account; hidden on Room Detail, Dispute Builder (and any other focused screens per design).
44. [ ] **Loading / error** — Trigger a failure (e.g. network off) where possible; error banner and retry appear; no infinite spinner or blank screen.
45. [ ] **Empty states** — Exports empty, Maintenance empty, no rooms: each shows intended empty message and one clear action.

---

## Sign-off

- **Phase A (routes) passed:** ☐ Yes  ☐ No — date: _______________
- **Phase B (E2E data) passed:** ☐ Yes  ☐ No — date: _______________
- **Phase C (security) passed:** ☐ Yes  ☐ No — date: _______________
- **Phase D (visual/state) passed:** ☐ Yes  ☐ No — date: _______________
- **Tester:** _______________

**Rule:** Do not mark Sprint 3 Item 13 / 15 complete until Phases A–C (and optionally D) are run and signed off. Use this order for a single test run; use `ROUTE_QA.md`, `E2E_QA.md`, and `SECURITY_QA.md` for detailed steps and isolation checks.
