# MoveMark — Build order

Full product build in phases. No random building; finish each phase before moving on.

---

## Phase 1 — Capture (core proof engine)

- [ ] **Walkthrough** — progress summary, next room CTA, room list with real completion states, custom room add, room counts reflect saved evidence
- [x] **Room Detail / Evidence Capture** — take/select photos, camera capture, notes, issue tags, condition rating, save evidence entries, show saved entries; per-entry edit, delete (with confirmation), append photos; move-in vs move-out compare in header; photo count updates in Vault/Walkthrough
- [ ] **Default + custom rooms** — default rooms always generate after Add Property, stable ordering, custom rooms append cleanly
- [ ] **Maintenance** — create issue, open/resolved sections, counts/statuses
- [x] **Move-out capture** — checklist, before/after room cards (move-in vs move-out snapshots, entry/photo counts, latest date, condition, condition delta), re-capture evidence, move-out report export; defensive copy and "Ready to export" when complete

**Next best target:** Room Detail / evidence capture (heart of the product).

---

## Phase 2 — Organize

- [x] **Supporting documents** — lease, deposit receipt, listing screenshots, cleaning receipt, utility proof, move-out invoice, other; upload, missing/uploaded state, replace (delete-then-upload), preview (signed URL in Safari), delete with confirmation
- [x] **Property details** — show landlord, email, phone, move-in, lease start/end, deposit, rent, country (Add Property full field parity; edit flow later)
- [x] **Property switching** — store holds `properties` + `activePropertyId`; Vault top-bar menu to switch; selection persisted per user in UserDefaults; switching clears nav stack
- [x] **Property edit flow** — EditPropertyView sheet from Vault detail "Edit"; pre-fill from PropertyRecord; save via PropertyRepository.updateProperty + store.updateProperty; fetchAll refreshes list and active property
- [x] **Account/settings** — AccountView: full name (editable via EditNameSheet), email (read-only), password reset email, app version/build, Privacy policy & Support links, sign out
- [x] **Vault + Walkthrough polish** — Vault: hero uses title/address, dynamic CTA (Start/Continue/Review), readiness header, rooms section subtitle; Walkthrough: progress card empty/all-complete states, "Open next room — Name" CTA, room list with Next pill and status, Add room card with icon and copy, empty room list state
- [ ] **Room statuses** — completion states reflected everywhere
- [ ] **Export history** — reliable list and share/open

---

## Phase 3 — Defend

- [ ] **Dispute Builder** — case setup (type, title, amount, summary, move-out date, itemized charge), evidence selection by category, packet strength, save draft, export packet
- [ ] **Packet strength** — selected counts, readiness, recommended missing pieces (later)
- [ ] **Export generation** — PDF/report output, letter preview (later)

---

## Phase 4 — Exports + reports

- [ ] **Export persistence** — move-in report, move-out report, dispute packet saved to DB
- [ ] **Signed URL / share** — reliable share and open from history
- [ ] **Export history screen** — reliable and consistent

---

## Sprint 3 — Reliability and launch readiness

- [x] **Item 11 — Loading / error / empty consistency** — MMErrorBanner + MMLoadingState + MMCopy; applied to Vault, Home, Add/Edit Property, Property Vault, Walkthrough, Room Detail, Maintenance, Move-out, Dispute Builder, Exports, Account, Onboarding; Maintenance and Move-out empty states added; see `docs/LOADING_ERROR_EMPTY.md`
- [x] **Item 12 — Retry behavior** — retry on evidence save, document upload (photo + file), maintenance add/update/photos, move-out checklist/export, walkthrough add room + move-in export, dispute load/save/export; form text preserved on failure (see `docs/LOADING_ERROR_EMPTY.md`)
- [ ] **Item 13 — Security verification** — plan ready: `docs/SECURITY_QA.md` (Phases 1–6 + summary checklist). **Not complete until script is run and signed off.** Run two-account test → tick checklist → sign off pass/fail; then mark done.
- [x] **Item 14 — Export / storage verification** — ExportVerificationStatus + ExportRepository.verify(); Export History per-row status (ready / missing / invalid / failed), Verify action, share updates status and shows MMErrorBanner on failure
- [ ] **Item 15 — End-to-end QA** — script: `docs/E2E_QA.md`. **Not complete until run and signed off.** Execute full path (sign in → onboarding → property → rooms → evidence → docs → maintenance → move-out → dispute → exports → sign out → relaunch), tick checklist, sign off.
- [ ] **Item 16 — Visual polish + TestFlight prep** — checklist: `docs/ITEM_16_POLISH_CHECKLIST.md` (typography/spacing, component consistency, screen-by-screen polish, release cleanup). Complete after or in parallel with Item 13/15 execution.

### Final completion sequence

1. **Run** `docs/QA_TEST_RUN_ORDER.md` (single run: route → E2E → security → visual). Stop at first failure; fix; re-run. Phases A–C required for Item 13/15 sign-off; Phase D for sanity.
2. **Sign off** `docs/SECURITY_QA.md` and `docs/E2E_QA.md` after Phase C and B respectively.
3. **Execute** `docs/ITEM_16_POLISH_CHECKLIST.md` (polish + TestFlight prep) → mark Item 16 complete.
4. Mark Sprint 3 complete.

### Architecture

**Vault:** VaultRootView is the signed-in shell (loading, empty, picker, error/recovery). PropertyVaultView is the property-scoped vault surface for the active property. UX name stays “Vault”; code is property-scoped; deep-linking can map to `vault/<propertyId>` later.

---

## Phase 5 — Production hardening

- [x] **Loading / error / empty** — MMErrorBanner, MMLoadingState, MMCopy; consistent error/loading/empty across major screens (Sprint 3 Item 11)
- [ ] **Loading / error / retry** — text preservation on failure, upload progress, network failure handling
- [ ] **Auth / session** — session restore confidence, signed-out fallback
- [ ] **Multi-account security** — user A cannot see user B property/docs; child records and storage paths scoped properly
- [ ] **Storage / export verification** — upload and export URLs scoped and tested

---

## Execution rule

Build in **vertical slices**: one feature with UI + persistence + error state, then move on. Example: finish Room Detail completely, then Documents, then Maintenance, then Move-out, then Dispute Builder.

Do not skip the proof capture engine to build payoff features first; the builder depends on real evidence, docs, and issues.
