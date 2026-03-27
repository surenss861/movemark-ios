# Smoke Test Checklist (post–PropertyStore split)

Run these **before** more refactors (e.g. PropertyVaultView / EvidenceCaptureView splits).  
If one fails, stop and fix that path before continuing.

**Recording:** Use 4 columns: **Flow** | **Expected** | **Actual** | **Repro steps**

---

## Pass 1 — App boot + vault list

### 1. Cold launch into authenticated state
- **Steps:** Launch app while already authenticated; let shell load.
- **Expected:** No flash of wrong empty state; vault list appears; no stale property; featured/current correct; no duplicate or blank cards; no crash.
- **Watch:** Empty state flash, wrong featured property, active not restored, lag before cards settle.

### 2. Empty-state sanity
- **Steps:** Use account with zero properties (or remove all). Launch.
- **Expected:** Empty state only; no ghost list; add-property CTA works; no stuck loading.
- **Watch:** `hasCompletedInitialFetch` wrong, spinner never leaves, stale previous property.

---

## Pass 2 — Property switching / selection

### 3. Open featured property from vault list
- **Steps:** Tap featured/current vault card; let detail load.
- **Expected:** Correct property; hero title/address match; readiness, rooms, docs all for that property; no stale data.
- **Watch:** Hero from one property but rooms/docs from another; active not switching before render; delayed hydration.

### 4. Switch between two properties
- **Steps:** Open A → back → Open B → back → Open A again.
- **Expected:** Each property loads its own rooms/docs/readiness; featured/current updates; no stale counts.
- **Watch:** `currentProperty` one step behind; featured card wrong; readiness/hero from wrong property.

---

## Pass 3 — Supporting records lifecycle

### 5. Upload doc that does NOT unlock exports
- **Steps:** Open property with missing docs; upload one doc; stay on vault.
- **Expected:** Row flips Missing → Uploaded; row highlights briefly; one toast, one haptic; count updates; Exports does **not** pulse unless it actually unlocked.
- **Watch:** Two toasts, wrong row highlight, count stale, exports pulsing incorrectly.

### 6. Upload doc that DOES unlock exports
- **Steps:** Property where one upload unlocks exports; upload that doc.
- **Expected:** Row highlights; Exports tile pulses; one toast (prefer “Exports unlocked”); one haptic; exports subtitle → ready.
- **Watch:** Wrong toast, subtitle stale, pulse twice.

### 7. Preview a document
- **Steps:** Tap View on uploaded doc.
- **Expected:** Correct document opens; no preview error unless URL fails; correct type.
- **Watch:** Signed URL failure, wrong bucket, wrong file from stale row.

### 8. Replace a document
- **Steps:** Replace existing doc; wait for upload; preview.
- **Expected:** Old file removed (storage lifecycle); row stays Uploaded; preview = new file; one toast, one haptic; no duplicate rows.
- **Watch:** Stale preview, duplicate DB rows, row flicker.

### 9. Delete a document
- **Steps:** Delete uploaded doc; confirm.
- **Expected:** Row → Missing; count down; preview gone; no crash if file missing; readiness/export update.
- **Watch:** Row still Uploaded, deleted row lingering, exports still “ready” when not.

---

## Pass 4 — Room evidence / queue logic

### 10. Complete the very first room
- **Steps:** Property with no documented rooms; open next room; save evidence; return to vault.
- **Expected:** One “room completed” toast; one haptic; new queue-head room pulses; walkthrough subtitle/readiness/hero update; documented count +1.
- **Watch:** Toast twice, wrong room pulsing, pulse not clearing, hero/readiness only after second open.

### 11. Add evidence to already-documented room
- **Steps:** Open room that already has evidence; save another entry; return to vault.
- **Expected:** **No** room-completed toast; **no** queue-head pulse; room still documented; counts may increase.
- **Watch:** `wasDocumentedOnLoad` wrong; duplicate completion feedback.

### 12. Complete a middle room (A done, B done, C next)
- **Steps:** A documented, B and C not; complete B; return to vault.
- **Expected:** Toast/haptic once; Room C = new next; Room C pulses; order: next → unfinished → finished; counts/readiness update.
- **Watch:** Wrong next room; `orderedRooms` sort glitch; stale next from fetch lag.

---

## Pass 5 — Readiness thresholds / action tiles

### 13. Cross readiness below 40 → above 40
- **Steps:** Property just below 40; action that bumps above 40.
- **Expected:** One toast; Dispute builder tile pulses; readiness band early → building.
- **Watch:** No pulse, pulse on every reappear, label ≠ score band.

### 14. Cross readiness below 70 → above 70
- **Steps:** Property just below 70; add proof to cross 70.
- **Expected:** Dispute tile pulses; readiness → strong; no duplicate pulse on revisit unless state changes again.
- **Watch:** Pulse every re-render; label stale; dispute + export pulse collision.

---

## Pass 6 — Maintenance / export consistency

### 15. Add maintenance issue
- **Steps:** Add maintenance issue; return to vault.
- **Expected:** Maintenance count updates; readiness may drop; maintenance tile subtitle → issue count; hero/summary reflect open issues.
- **Watch:** Open issues count stale; readiness not recalculating; tile still “Track reported problems”.

### 16. Resolve or remove maintenance issue
- **Steps:** Resolve/close issue; return to vault.
- **Expected:** Count down; readiness can improve; summaries consistent.
- **Watch:** Count stale; readiness not recomputing.

---

## Pass 7 — Fast navigation / edge timing

### 17. Back out quickly after room save
- **Steps:** Save room evidence; navigate back quickly; return to vault.
- **Expected:** One completion feedback; next-room pulse matches actual next room; no race.
- **Watch:** Pulse on wrong room; toast without count update; event consumed before state ready.

### 18. Rapid property switch after mutation
- **Steps:** Upload doc or complete room in A; immediately back → open B; return to A.
- **Expected:** Feedback for correct property; no cross-property pulse/toast; active/current accurate.
- **Watch:** Pending vault feedback on wrong property; highlight/pulse on wrong screen; currentProperty lag.

---

## Pass 8 — Storage correctness

### 19. Replace then delete same document
- **Steps:** Upload → replace → delete.
- **Expected:** No crash; row ends Missing; no stale preview; DB row gone; storage lifecycle doesn’t block.
- **Watch:** Stale preview, duplicate rows, delete failing silently.

### 20. Delete evidence entry with photos
- **Steps:** Create evidence with photos; delete that entry; reload/revisit.
- **Expected:** Entry gone; room/documented state correct; no orphan refs; no crash on rehydrate.
- **Watch:** Deleted entry visible until second refresh; room still “documented”; file rows gone but summary stale.

---

## Order to run

**First:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9  
**Second:** 10 → 11 → 12  
**Third:** 13 → 14 → 15 → 16  
**Fourth:** 17 → 18 → 19 → 20  

**Bug report format:**
- **Start screen:**
- **Action:**
- **Expected:**
- **Actual:**
