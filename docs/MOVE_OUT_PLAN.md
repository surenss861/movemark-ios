# Move-out — Build summary

## Current state (v1)

### Done
- **MoveOutFoundationView** — Header with defensive copy ("before-and-after record is what protects you if the landlord disputes condition or deposit"), **move-out readiness summary** titled "Your move-out defense" (rooms with move-out proof X of Y, checklist N of 6, "Ready to export" pill when both complete), **checklist card** (6 toggles) with load/save, **before/after room cards** (rich compare), export card. Accepts **`@Binding var path: [AppRoute]`** and uses **`path.append(.moveOutRoomDetail(roomID:))`** for room capture.
- **Before/after room cards** — Each room card shows: room name + checkmark if move-out proof exists; **Move-in** block (entries, photos, latest date, condition) vs **Move-out** block (same, or "No proof"); **condition delta** line ("Condition unchanged (4/5)." or "Condition 4/5 → 3/5." or "No move-out yet — capture to compare condition."); CTA line ("Tap to capture move-out proof" vs "Tap to add more move-out proof or review."). Data from `room.evidence` and `room.moveOutEvidence` (latest = `.first` after hydration sort).
- **AppRoute.moveOutRoomDetail(roomID: UUID)** — Push route for move-out room capture. Handled by **MoveOutRoomDetailDestinationView** (resolves room name from store, presents **EvidenceCaptureView(..., moveOutMode: true)**).
- **EvidenceCaptureView** — **`moveOutMode: Bool = false`**. When true: **existingEntries** = `room?.moveOutEvidence`; header/card/section labels and button use move-out copy ("Add move-out proof", "Save move-out proof", "Saved move-out proof"); **save** calls **`propertyStore.addMoveOutEvidence`** and builds evidence with **stage: .moveOut**; success message "Move-out proof saved to your vault." Walkthrough room detail still uses **moveOutMode: false** (RoomDetailDestinationView).
- **Checklist** — **ChecklistRepository**: `fetchChecklist(propertyId:userId:)`, `upsertChecklist(_:)` on `move_out_checklists` (upsert on property_id, user_id). New checklist row created with **id: UUID()** so insert has a primary key. Toggles update local state and call **saveChecklist(updated)**.
- **PropertyStore.addMoveOutEvidence** — Upserts move-out inspection, inserts inspection item, uploads photos to inspection-media, links evidence_files, then **fetchAll(userId)** so rooms and moveOutEvidence refresh.

### Flow
1. User opens Move-out → checklist loads (or creates with id), "Your move-out defense" summary shows rooms-with-move-out and checklist completion; "Ready to export" when both full.
2. Toggle checklist item → **saveChecklist** → upsert to DB.
3. Room cards show before/after: move-in vs move-out entry counts, photo counts, latest date, condition; condition delta line when both exist; tap → **path.append(.moveOutRoomDetail(roomID:))** → **EvidenceCaptureView(..., moveOutMode: true)** → save → **addMoveOutEvidence** → **fetchAll** → back to Move-out, card updates with new move-out snapshot and delta.
4. Export card: "Generate a move-out report with your before-and-after room proof..." — PDF + export row + share; report content aligned with same room/evidence data.

### Later
- Link "Cleaning receipt uploaded" to supporting documents (e.g. upload to property_documents and auto-check when doc type present).
- Move-out report handoff to Dispute Builder / export pipeline.
