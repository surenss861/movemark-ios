# Sprint 3, Item 13 — Security verification

Two-account QA to prove **user A cannot see or access user B data** and **sign-out / account switch does not leak state**.

**Status:** Plan and checklist are ready. **Item 13 is not complete until this script is run and the summary checklist is signed off.** Run Phases 1–6, tick the boxes, then sign off pass/fail.

---

## Prerequisites

- Two real test accounts (e.g. **Account A** and **Account B**) with different emails.
- Same simulator or device for the whole run (no cross-device).
- Supabase project with RLS enabled and policies applied (see `supabase/migrations/20260312000006_rls_enable.sql`, `20260312000007_rls_policies_direct.sql`, `20260312000008_rls_policies_indirect.sql`).

---

## What RLS enforces (reference)

| Layer | Tables | Policy basis |
|-------|--------|--------------|
| **Direct** | `profiles`, `properties`, `inspections`, `maintenance_issues`, `property_documents`, `move_out_checklists`, `move_out_checklist_state`, `disputes`, `exports` | `auth.uid() = user_id` |
| **Indirect** | `rooms` | via `properties.user_id` |
| | `inspection_items` | via `inspections.user_id` |
| | `evidence_files` | via property / inspection / maintenance_issue ownership |
| | `inspection_item_tags` | via inspection_items → inspections.user_id |
| | `dispute_evidence_links` | via `disputes.user_id` |

Storage: paths in app use `userId` and `propertyId`; ensure storage buckets have policies that restrict by path or equivalent so User B cannot read User A’s objects.

---

## Phase 1 — Account A: create data

Use **Account A** only. Complete each step and note any failures.

1. **Sign in** as Account A.
2. **Create a property**
   - Add property (e.g. “A’s Test Property”, full address).
   - Confirm you land in Vault and see the property.
3. **Rooms & evidence**
   - Open Walkthrough.
   - Open one room (e.g. Living Room).
   - Add at least one proof entry (photo + note + save).
   - Confirm it appears in Room Detail and back in Walkthrough.
4. **Supporting documents**
   - In Vault, upload at least one document (e.g. lease or listing screenshot).
   - Confirm it shows as attached.
5. **Maintenance**
   - Open Maintenance.
   - Create one issue (title, category, optional details/photos, save).
   - Confirm it appears in the list; open it and confirm detail.
6. **Move-out** (optional but recommended)
   - Open Move-out.
   - Toggle at least one checklist item (so checklist is saved).
   - Optionally capture move-out proof for one room.
7. **Dispute Builder**
   - Open Dispute Builder.
   - Fill case setup (type, title, amount, summary, dates if used).
   - Select at least one room evidence and/or document.
   - Save draft.
   - Optionally export simple PDF and/or generate formal packet.
8. **Exports**
   - Open Exports (Export History).
   - Confirm at least one export row appears (move-in, move-out, or dispute), and that Share works if you use it.

**Checkpoint:** Account A has property, rooms, evidence, docs, maintenance, optional move-out and dispute/export data. No Account B data exists yet.

---

## Phase 2 — Sign out, sign in as B, verify isolation

1. **Sign out** Account A (Account → Sign out).
2. Confirm you are on **Welcome / Auth** (no Vault, no property).
3. **Sign in** as **Account B** (second test account).
4. **Vault**
   - [ ] No property from A is shown (empty state or B’s own properties only).
   - [ ] If B has no property yet, you see “No property yet” / Add property (not A’s property).
5. **Create B’s property**
   - Add a property for B (e.g. “B’s Test Property”).
   - Confirm Vault shows only B’s property.
6. **Walkthrough**
   - [ ] Room list is for B’s property only (default or B’s rooms).
   - [ ] No room evidence from A (no A’s photos/notes).
7. **Room Detail** (any room)
   - [ ] No saved proof from A; only B’s data if B added any.
8. **Supporting documents** (Vault)
   - [ ] No documents from A; only “Not uploaded yet” or B’s uploads.
9. **Maintenance**
   - [ ] No issues from A; only empty list or B’s issues.
10. **Move-out**
    - [ ] Checklist is empty or B’s only; no A checklist or move-out proof.
11. **Dispute Builder**
    - [ ] No draft from A; empty or B’s draft only.
12. **Export History**
    - [ ] No exports from A; empty or only B’s exports.

**Checkpoint:** On the same device, after sign-out and sign-in as B, **none of A’s data** appears in Vault, Walkthrough, Room Detail, documents, Maintenance, Move-out, Dispute Builder, or Export History.

---

## Phase 3 — Signed URLs and storage (no cross-user content)

1. As **Account B**, if you have an export or document that generates a link (e.g. Share / Preview):
   - [ ] Open/share the link; confirm it shows B’s content (or “no access” if expired), **not** A’s.
2. As **Account A** again (sign out B, sign in A):
   - [ ] Preview/share A’s document or export; confirm it shows A’s content, **not** B’s.

If you have no signed-URL flow yet, note “N/A – verify when preview/share is used” and retest when implemented.

---

## Phase 4 — Sign back to A, verify A’s data and no B leak

1. **Sign out** Account B.
2. **Sign in** again as **Account A**.
3. **Vault**
   - [ ] A’s property (e.g. “A’s Test Property”) is visible.
   - [ ] No property belonging to B is visible (unless you explicitly shared something; normal case is no B data).
4. **Walkthrough / Room Detail**
   - [ ] A’s rooms and evidence are present; no B’s rooms/evidence mixed in.
5. **Supporting documents**
   - [ ] A’s uploaded docs are present; no B’s docs.
6. **Maintenance**
   - [ ] A’s issues only; no B’s issues.
7. **Move-out**
   - [ ] A’s checklist and move-out proof only.
8. **Dispute Builder**
   - [ ] A’s draft and evidence selections; no B’s draft.
9. **Export History**
   - [ ] A’s exports only; no B’s exports.

**Checkpoint:** After switching back to A, **only A’s data** is shown; no stale B data or cross-contamination.

---

## Phase 5 — Property switching (same account)

1. As **Account A**, if A has **multiple properties**:
   - [ ] Use the property switcher in Vault; switch to another A property.
   - [ ] Vault, Walkthrough, documents, Maintenance, Move-out, Dispute Builder, and Export History all reflect the **selected property** (e.g. correct rooms, docs, issues, exports for that property).
   - [ ] Switch back to the first property; again all data matches the selected property.
2. [ ] No data from **another user** appears when switching between **A’s** properties.

**Checkpoint:** Property switching only changes which of the **current user’s** properties is active; no cross-user data and no wrong-property data.

---

## Phase 6 — Child tables (in-app behavior)

RLS already ties child data to the owning user via parent tables (e.g. rooms → properties.user_id, evidence_files → property/inspection/maintenance). The app only loads data through current user’s properties/disputes. This phase is a quick sanity check:

1. As **Account A**, open a room that has evidence.
   - [ ] Evidence list and photos are for that room/property only.
2. As **Account B**, create a property and add one maintenance issue.
   - [ ] In Maintenance, only B’s issue appears; in Issue Detail, only B’s issue content.
3. As **Account A**, open Dispute Builder and load draft.
   - [ ] Selected evidence/docs/maintenance IDs resolve to A’s data only (no B’s IDs or content).

**Checkpoint:** Child data (evidence, documents, maintenance, dispute links, exports) is scoped to the signed-in user and the selected property; no cross-user or wrong-property rows.

---

## Summary checklist (run and tick)

| # | Check | Pass |
|---|--------|------|
| 1 | Two separate test accounts created/used | ☐ |
| 2 | User A cannot see User B properties | ☐ |
| 3 | User A cannot see User B rooms/evidence | ☐ |
| 4 | User A cannot see User B maintenance issues | ☐ |
| 5 | User A cannot see User B documents | ☐ |
| 6 | User A cannot see User B disputes | ☐ |
| 7 | User A cannot see User B exports | ☐ |
| 8 | Signed URLs / storage do not leak cross-user content | ☐ |
| 9 | Sign out + sign in as another user clears old state (no A data as B, no B data as A) | ☐ |
| 10 | Property switching (same account) does not cross-contaminate; no other user’s data | ☐ |
| 11 | Child tables: only current user’s data in evidence, docs, maintenance, dispute, exports | ☐ |

---

## If something fails

- **DB leak:** Check RLS policies for that table (and parent tables for indirect policies). Ensure `auth.uid()` is used and no service role in app.
- **Stale UI after sign-out:** Ensure `PropertyStore.clear()` (or equivalent) runs on sign-out and that Vault/views refetch after sign-in (no cached B data when A signs in).
- **Wrong data after property switch:** Ensure active property is updated and all lists (rooms, docs, maintenance, disputes, exports) are refetched for the selected property and current user.
- **Storage/signed URL:** Ensure paths include `user_id` (and ideally `property_id`) and that storage policies or signed-URL generation do not allow access to another user’s objects.

---

## Sign-off

- **Date run:** _______________
- **Tester:** _______________
- **All checks passed:** ☐ Yes  ☐ No (describe in ticket or doc): _______________

Once all items pass, Sprint 3 Item 13 (Security verification) can be marked complete.
