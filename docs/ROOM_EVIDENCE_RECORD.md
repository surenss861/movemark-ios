---
related-code:
  - "[[EvidenceCaptureView.swift]]"
  - "[[RoomEvidenceHero.swift]]"
  - "[[RoomEvidenceBody.swift]]"
  - "[[RoomProofScreen.kt]]"
  - "[[RoomEvidenceHero.kt]]"
  - "[[RoomEvidenceBody.kt]]"
  - "[[RoomProofViewModel.kt]]"
  - "[[PropertyStore.kt]]"
  - "[[InspectionRepository.kt]]"
  - "[[MMRichQAGallery.swift]]"
  - "[[RichQAActivity.kt]]"
domain: proof-capture
type: spec
status: wip
author: suren
tags: [movemark, room, evidence, ios, android]
---

# Room: "This evidence is preserved"

Room is the most important visual surface in MoveMark, because it holds the actual evidence. It applies [[VISUAL_STANDARD]]. The Figma "MoveMark — Inspo V2" has no Room frame, so Room takes that file's language (a photographic dark hero, confident sans type, green only as a signal, glass over imagery) and pushes it further.

## 1. Critique of the previous Room

- **The plate was a card on a page, not a photograph.** The 4:3 plate sat inside screen margins under a title, so the evidence was framed like an attachment.
- **Everything had equal weight.** Hero, picker, a form card, and a saved list where each entry was its own card made four stacked rectangles with no star.
- **The form was always visible.** Title, tags, notes and condition sat open even before there was a photo to describe, so the screen read as a form to fill in, not evidence to look at.
- **The save bar was permanent.** A disabled "Add photos to continue" bar took space on every visit, including rooms that were already finished.
- **Photos were small.** Saved photos appeared as 76pt thumbnails inside each entry card, and there was no way to browse the room's evidence as a set.
- **The serif title** came from the earlier editorial direction, which is now retired.
- **Android only had** the hero, a picker and a save bar. It saved condition "Good" with empty notes and no tags, and had no way to edit, add photos to, or delete a saved entry.

## 2. What we keep

- The plate's logic: the latest saved photo for the phase is the hero, condition / photo count / issue chips, the mono `RECORDED` time, phase awareness, and the move-in vs move-out comparison line.
- Honest upload states: preparing, uploading N of M, partial failure with retry, failed. Uploads keep running if you leave the screen.
- The camera permission flow, the 20-photo picker limit, iOS downsampling, and Android's per-photo upload with thumbnails.
- The existing iOS edit and add-photos sheets, the full-screen photo preview, and the delete confirmation copy ("Photos and notes for this entry will be removed. This can't be undone.").
- Safe deletion order, the same on both platforms: files from storage, then file rows, then tag links, then the item.

## 3. What Android was missing (closed in this change)

| Capability | Before | Now |
|---|---|---|
| Condition on save | hard-coded 4 | picker, default Good |
| Issue tags | none | same six tags as iOS, saved through `issue_tags` |
| Title and notes | room name, empty notes | editable; stored as `title\nnotes`, as on iOS |
| Saved-entry list | none | entries with Edit, Add photos, Delete |
| Edit an entry | none | updates the item, then replaces its tags (iOS order) |
| Add photos to an entry | none | appends; a failed batch never deletes the entry |
| Delete an entry | none (tags weren't deleted either) | iOS order, with tags removed before the item |
| Tag names and thumbnails in the model | count only | names and `thumbnail_path` hydrated from the snapshot |

## 4. Composition

The screen is dark, because evidence is viewed like a photo library. There are no stacked cards: hierarchy comes from the image, type, spacing and hairline dividers. **At most one green action is visible at a time.**

### Empty room

```text
‹ (glass)                                       Move-in
                                                         dark field, no fake image
LIVING ROOM                                              kicker
Still needs proof                                        34pt sans bold
Photograph it before boxes cover anything.

WHAT TO CAPTURE
○ A wide shot from the doorway
○ Walls and baseboards
○ Floors
○ Windows / blinds

[ Take photos ]               ← the one green action
[ Choose from gallery ]       ← secondary
```

On Android, the capture list drops "Tag visible damage" / "Add notes". Those are now done in the form (below) on both platforms, so they are no longer prompts on either platform.

### Room with one photo

```text
┌──────────── full-bleed photo (under the status bar) ────────────┐
│ ‹ (glass)                                      Move-in (glass)  │
│                                                                 │
│                                                                 │
│ MOVE-IN EVIDENCE                                                │
│ Primary Bedroom                     ← 34pt sans over a gradient │
│ (Good) (1 photo)                    ← glass chips               │
└─────────────────────────────────────────────────────────────────┘
RECORDED  OCT 19 · 6:37 PM

CONDITION   Good  ▮▮▮▮▯
────────────────────────────
ENTRIES
Primary Bedroom            1 photo   ···
OCT 19 · 6:37 PM
────────────────────────────
ADD MORE PROOF
[ Take photos ]  [ Gallery ]          ← secondary: the room is already documented
```

### Room with many photos

The same hero, plus a **filmstrip** under it: every photo in the phase, newest first, as 64pt thumbnails. Tapping a thumbnail swaps the hero, with a crossfade (no crossfade under Reduce Motion). Tapping the hero opens the full-screen viewer. The chip shows the total ("12 photos"), and each entry row shows its own count.

### Room with damage

The hero chip reads "2 issues" with an amber tint. A **DAMAGE NOTED** section sits under Condition, with amber tag pills ("Scratch", "Water damage") and the entry notes as body text. Amber here is attention, not error.

### Adding proof (any state)

After photos are picked, a **NEW ENTRY** section appears with the pending-photo grid and per-photo upload status, then the details: title, condition, issue tags and notes. A floating **Save proof** bar (green) appears only now. During a save it reads "Uploading 2 of 5". A partial failure shows "Retry failed photos" and keeps the saved photos.

## 5. Files

- **iOS:** `EvidenceCaptureView.swift`, plus new `RoomEvidenceHero.swift` (full-bleed hero, empty field, filmstrip) and `RoomEvidenceBody.swift` (condition, damage, entries, add-more). The form and save bar are restyled. `MMRoomEvidencePlate.swift` is replaced by the hero.
- **Android:** `RoomProofScreen.kt` and `RoomProofViewModel.kt` (form state, edit / append / delete), plus new `RoomEvidenceHero.kt` and `RoomEvidenceBody.kt`. Data: `PropertyModels.kt`, `PropertyHydrator.kt`, `InspectionRepository.kt`, `PropertyStore.kt`, `EvidenceUploadContext.kt`.
- **QA:** `MMRichQAGallery.swift` and `RichQAActivity.kt` room cases.

## 6. Runtime QA matrix

Fixture runs use the debug galleries with drawn photos: `-MMRichQA room-*` on iOS, and `RichQAActivity --es case room-*` on Android. ✅ = checked on screen, ⏳ = not yet run.

| Case | iOS default | iOS AX3 | Android 1.0× | Android 2.0× | Live (signed in) |
|---|:-:|:-:|:-:|:-:|:-:|
| Empty room (`room-empty`) | ✅ | ✅ | ✅ | ✅ | ⏳ |
| One photo (`room-one`) | ✅ | ⏳ | ✅ | ⏳ | ⏳ |
| Many photos + filmstrip (`room-many`) | ✅ | ⏳ | ✅ | ⏳ | ⏳ |
| Damage: tags and notes (`room-damage`) | ✅ | ✅ | ✅ | ✅ | ⏳ |
| Move-out, both phases (`room-moveout`) | ✅ | ⏳ | ✅ | ⏳ | ⏳ |
| Dark photo (`room-dark`) | ✅ | ⏳ | ✅ | ⏳ | ⏳ |
| Long room name (`room-long`) | ✅ | ⏳ | ✅ | ✅ | ⏳ |
| Pending photos + form + save bar (`room-pending`) | ✅ | ⏳ | ✅ | ⏳ | ⏳ |
| Upload failure → retry | — | — | — | — | ⏳ |
| Edit / Add photos / Delete entry | — | — | — | — | ⏳ |
| Small phone (iPhone SE / 360dp) | ⏳ | — | ⏳ | — | ⏳ |

### Fixed during QA
- **iOS:** the fill-cropped hero image widened the whole screen, pushing the condition meter, menu and buttons off the right edge. The photo now sits in an overlay inside a fixed frame.
- **iOS AX3:** the kicker lost contrast over pale walls. The gradient now starts higher and the title has a soft shadow.
- **iOS AX3:** "Choose from gallery" was clipped by its fixed height. It now uses a minimum height.
- **Both:** the gallery button now matches the secondary "Take photos" surface, and the save bar floats as material (iOS) or a translucent bar with a hairline (Android) instead of a slab.

### Still open
- **Live runs.** The new Android save (condition, tags, notes), edit, add photos and delete call the backend but have only been compiled, not run against it. They need a signed-in session on the emulator.
- **Hero scroll response** (a gentle parallax or stretch) is deliberately not built yet. It's the next motion detail once the static composition is approved.

## Reference pass (2026-10-19)

Following the locked references (`design-refs/room-dark-set.jpg`, screens 2, 3, 6 and 7; see [[VISUAL_STANDARD]]), the photo now plays the poster:

- **Hero:** about two-thirds of the screen. Chips with icons come first (condition ✓, photos, issues ⚠), then the room name, then the RECORDED time, all on the photo.
- **Add evidence:** a **white "Add evidence" pill** in the hero opens camera or library. The "Add more proof" section is gone; green stays reserved for saving.
- **Scroll:** pulling down stretches the photo (iOS). Scrolling up gives a parallax drift (both). The room name settles into the bar once the hero leaves (both). All of it is off under Reduce Motion.
- **Viewer:** a paging viewer with a "2 of 4" counter and a filmstrip. It pages through every photo in the phase, newest entry first, on both platforms.

| Case | iOS | Android |
|---|:-:|:-:|
| Damage hero (chips, title, recorded, pill) | ✅ | ✅ |
| One photo | ✅ | — |
| Viewer `room-viewer` ("2 of 4", filmstrip) | ✅ | ✅ (filmstrip was under the gesture bar; fixed) |
| Title in bar after scroll | build only | ✅ |
| Parallax on scroll | build only | ✅ |
| Empty | ✅ | ✅ |

iOS scroll effects are compiled but not yet seen on screen: the simulator can't be swiped from the command line. They need a hands-on check.
