# Sprint 3, Item 16 — Visual polish + TestFlight prep

Final build pass before "done." Run after Item 13 and Item 15 are executed and signed off (or in parallel with QA).

---

## Prioritized punch list (fastest execution order)

Do in this order so one pass benefits many screens, then hit high-traffic screens first.

| Phase | What | Why first |
|-------|------|-----------|
| **A** | Global: typography + component consistency (§1, §2) | One pass fixes the system; every screen benefits. |
| **B** | Primary: Vault → Walkthrough → Room Detail | Most-used surfaces; biggest perceived quality gain. |
| **C** | Secondary: Welcome/Auth → Maintenance → Move-out → Dispute Builder → Exports → Account | Remaining screens in flow order. |
| **D** | Release cleanup (§4) | Logs, version, URLs, copy, icon; do last so polish is stable. |

**Execution:** Complete Phase A, then run through Phase B screens in order, then Phase C, then Phase D. Tick the detailed checkboxes in §§1–4 as you go.

**Punch list (tick in order):**

- [ ] **A** — Typography & spacing (§1)
- [ ] **A** — Component consistency (§2)
- [ ] **B** — Vault
- [ ] **B** — Walkthrough
- [ ] **B** — Room Detail
- [ ] **C** — Welcome / Auth
- [ ] **C** — Maintenance (list + detail)
- [ ] **C** — Move-out
- [ ] **C** — Dispute Builder
- [ ] **C** — Exports
- [ ] **C** — Account
- [ ] **D** — Release cleanup (§4)

---

## 1. Typography & spacing

- [ ] **Headers** — Section/screen titles feel serious and consistent (weight, size, color). No bubbly or generic feel.
- [ ] **Body** — Line height and spacing consistent; no cramped or over-spaced blocks.
- [ ] **Section headers** — One pattern (e.g. MMSectionHeader or equivalent) used everywhere; no ad-hoc titles.
- [ ] **Reduction** — Remove visual repetition (e.g. duplicate headings, redundant labels).

---

## 2. Component consistency

- [ ] **Cards (MMCard)** — Same corner radius, padding, stroke; one design system.
- [ ] **Buttons** — Primary vs secondary hierarchy clear; heights and corner radii consistent (MMButton usage).
- [ ] **Pills/chips (MMPill)** — Tones and sizes consistent; no one-off chip styles.
- [ ] **Banners / loading** — MMErrorBanner, MMLoadingState, ProgressView usage consistent; no random spinners or error styles.
- [ ] **Form fields** — MMTextField and similar: consistent height, radius, placeholder style.

---

## 3. Screen-by-screen polish

### Welcome / Auth

- [ ] Typography and spacing feel premium, not template-y.
- [ ] Sign in / Sign up hierarchy clear; no floating or misaligned elements.
- [ ] Error states use MMErrorBanner or agreed pattern.

### Vault (PropertyVaultView)

- [ ] Hero (VaultHeroCard) hierarchy clear; CTA and progress ring feel intentional.
- [ ] Rooms strip / section readable; "X of Y documented" and next step obvious.
- [ ] Supporting records section tidy; document rows and actions aligned.
- [ ] Property details block readable; edit flow obvious.
- [ ] No duplicate headings or noisy labels.

### Walkthrough (RoomListView)

- [ ] Progress card (no rooms / in progress / all complete) clear; next CTA strong.
- [ ] Add room card and room list feel from same system; states (next, complete, not started) obvious.
- [ ] Move-in report and Move-out entry points clear.

### Room Detail (EvidenceCaptureView)

- [ ] Room hero/summary and move-in vs move-out compare readable.
- [ ] Tag picker and condition control aligned; saved proof cards consistent.
- [ ] Camera / photo actions and loading states clear.

### Maintenance (MaintenanceLogView + Detail)

- [ ] Composer and issue list spacing consistent.
- [ ] Open vs resolved sections clear; issue cards and detail layout tidy.
- [ ] Follow-up and resolve actions obvious; no dead space or clutter.

### Move-out (MoveOutFoundationView)

- [ ] Readiness summary and "Ready to export" state clear.
- [ ] Before/after room cards readable; condition delta and CTAs obvious.
- [ ] Checklist and export card feel part of same screen.

### Dispute Builder

- [ ] Case setup, evidence selection, packet strength, and export cards flow; hierarchy clear.
- [ ] Empty states (no property, no evidence) and success/error states consistent.
- [ ] Save draft and export buttons obvious; loading states clear.

### Exports (ExportHistoryView)

- [ ] Section headers and empty state consistent with rest of app.
- [ ] Per-row status (ready / missing / invalid) and Verify/Share actions readable.
- [ ] No duplicate or noisy copy.

### Account (AccountView)

- [ ] Profile, email, password reset, version/build, and links tidy.
- [ ] Sign out prominent; edit name flow clear.
- [ ] Privacy/support placeholders noted for replacement when URLs exist.

---

## 4. Release cleanup (TestFlight prep)

- [ ] **Debug logs** — Remove or gate `print(...)` used for development (e.g. 🟢, 🏪, 📦, 👋, 🚀, 🧭, etc.). Keep only what’s needed for support or critical errors.
- [ ] **Version / build** — Account screen (or equivalent) shows correct app version and build from `Bundle.main.infoDictionary`.
- [ ] **Placeholder URLs** — Privacy policy and Support/contact links: replace with real URLs if available; otherwise document as placeholders.
- [ ] **Camera permission** — `NSCameraUsageDescription` in Info.plist is user-facing and clear.
- [ ] **Empty / error copy** — Final pass: no developer-only messages; MMCopy and MMErrorBanner copy appropriate for production.
- [ ] **App icon / metadata** — Confirm icon and display name for TestFlight/App Store (later step; note here).

---

## Sign-off

- **Date:** _______________
- **Polish complete:** ☐ Yes  ☐ No (notes): _______________
- **TestFlight prep complete:** ☐ Yes  ☐ No (notes): _______________

After this pass and any fixes from Item 13/15, mark Item 16 complete. Sprint 3 is then complete.
