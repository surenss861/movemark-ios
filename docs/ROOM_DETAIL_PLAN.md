# Room Detail / Evidence Capture — Build plan

## Current state (after this pass)

### Done
- **EvidenceCaptureView** — Room hero, photo strip, condition picker, **fixed issue tag picker** (chips), notes, Save evidence. Saved proof section shows entries with title, date, tags, notes, photo count, condition. Nav title = room name. **Hero summary row**: total entries, total photos, latest date when evidence exists.
- **PropertyStore.addEvidence / addMoveOutEvidence** — Persist inspection item, upload photos, evidence_files, inspection_item_tags. **Now call `fetchAll(userId)` after save** so Vault and Walkthrough counts refresh.
- **PropertyStore.fetchAll** — **Now hydrates real EvidenceRecords** from DB: inspection_items (notes → title/notes, condition_rating, createdAt), evidence file count per item, issue tag names per item. Saved list and hero show real data after reload.
- **InspectionRepository.fetchItemTagNames** — Returns tag names per inspection item id for evidence hydration.
- **Save validation** — At least one photo required; error "Add at least one photo." if none.
- **Loading / success** — Button shows "Saving proof…" while uploading; form dimmed and non-interactive; success copy "Proof saved to your vault."
- **Seed migration** — `20260313000001_seed_issue_tags.sql` seeds `issue_tags` with: Scratch, Stain, Water damage, Chipped paint, Cracked tile, Appliance damage, Scuff marks, Loose fixture (safe to re-run).

### Save flow (current)
1. User selects at least one photo, optional title/notes, optional tags (fixed picker), condition.
2. Tap **Save evidence** → validation (require ≥1 photo) → `propertyStore.addEvidence(...)`.
3. Store: upsert move-in inspection → insert inspection_item → upload photos → insert evidence_files → insert item tags (by name, for tags in `issue_tags`) → **fetchAll(userId)**.
4. UI: room.evidence from store; hero summary and saved list show real data.

### Issue tags
- **Fixed picker** in EvidenceCaptureView: 8 tags (Scratch, Stain, Water damage, Chipped paint, Cracked tile, Appliance damage, Scuff marks, Loose fixture). Selected tags saved via existing `insertItemTags` (tags must exist in `issue_tags`; seed migration ensures they do).

---

## Room Detail v1 checklist (reference)

- [x] Load room context
- [x] Show room hero / placeholder
- [x] Show photo strip
- [x] Show condition rating control
- [x] Fixed issue tag picker (chips)
- [x] Show notes field
- [x] Photo picker
- [x] Save proof action
- [x] Persist inspection item + evidence files + tags
- [x] Reload saved entries (real data from fetchAll)
- [x] Sync room completion state to Walkthrough (fetchAll)
- [x] Sync counts to Vault (fetchAll)
- [x] Nav title = room name
- [x] Loading/success: "Saving proof…", dim form, "Proof saved to your vault."
- [x] Validation: require at least one photo
- [x] Hero summary row (entries, photos, latest date)
- [x] Camera-native capture (`CameraCaptureView` + Take photo button; `NSCameraUsageDescription` in Info.plist)
- [x] Per-entry edit (EditEvidenceSheet: title, notes, tags, condition; `PropertyStore.updateEvidence` + `InspectionRepository.updateInspectionItem` / deleteItemTags / insertItemTags)
- [x] Per-entry delete (confirmation dialog; `PropertyStore.deleteEvidence` → `InspectionRepository.deleteInspectionItem` cascades evidence_files + inspection_item_tags)
- [x] Append photos to entry (AppendPhotosSheet; `PropertyStore.appendPhotosToEvidence` → `InspectionRepository.appendPhotosToInspectionItem`)
- [x] Move-in vs move-out compare (room header: "Move-in: X entries, Y photos · Move-out: A entries, B photos")
- [ ] Later: real photo thumbnails in hero via signed URLs

---

## Next (later phases)

- **Walkthrough** — Progress and room cards already use `room.evidence`; with real hydration they show correct completion and counts.
- **Move-out** — Same flow with `addMoveOutEvidence`; move-out evidence list and before/after by room.
- **Dispute Builder** — Evidence selection can use the same EvidenceRecords.
