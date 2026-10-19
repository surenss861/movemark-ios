---
related-code:
  - "[[MMRoomEvidencePlate.swift]]"
  - "[[MMRoomEvidencePlate.kt]]"
  - "[[EvidenceCaptureView.swift]]"
  - "[[EvidenceCaptureHero.swift]]"
  - "[[RoomProofScreen.kt]]"
  - "[[RoomProofCaptureHero.kt]]"
  - "[[MMRichQAGallery.swift]]"
  - "[[RichQAActivity.kt]]"
domain: proof-capture
type: spec
status: wip
author: suren
tags: [movemark, room, evidence, ios, android]
---

# Room: "This room has a preserved evidence record"

Room is where the actual evidence lives, so it is the richest screen in the app. It applies [[VISUAL_STANDARD]].

## Hero: the evidence plate

The hero is the room's evidence plate, with the photograph as the star:

```text
MOVE-IN EVIDENCE                ← kicker, tracked sans
Primary Bedroom                 ← editorial serif

┌──────────────────────────────┐
│                              │
│   latest evidence photo      │  4:3, rounded, full width
│                              │
│ (Good) (4 photos) (1 issue)  │  ← glass chips over the photo
└──────────────────────────────┘
RECORDED  OCT 19 · 12:15 PM     ← kicker + mono
```

- **Photo:** the first photo of the most recent saved entry for this phase (move-in or move-out). The plate loads the thumbnail when one exists and falls back to the full file.
- **Chips** (glass, over the bottom of the photo): the latest entry's condition, the total photo count for the phase, and the issue-tag count (only when above zero).
- **Recorded:** the latest entry's capture time in mono.
- **Move-out mode:** the kicker reads `MOVE-OUT EVIDENCE`. When both phases have photos, a mono line underneath reads `MOVE-IN 4 · MOVE-OUT 3 PHOTOS`.

### Empty state: "Still needs proof"

When the phase has no saved photos, the same 4:3 frame becomes an empty capture surface: a hairline frame with a camera glyph, the line **Still needs proof**, and, for move-in only, the shot prompts as quiet guidance. The green call to action stays in the capture controls below; the empty plate never adds a second one.

## Below the hero

The order is the same on both platforms:

1. Capture controls (camera, library) and pending photos
2. Condition, issue tags, notes (iOS today; Android does not have these yet, see below)
3. Saved evidence for this phase
4. Bottom save bar (the only green action on the screen)

## Parity status (2026-10-19)

| Capability | iOS | Android |
|---|:-:|:-:|
| Evidence plate (photo hero, chips, recorded time, empty state) | ✅ | ✅ |
| Pending-photo capture and save bar | ✅ | ✅ |
| Condition picker, issue tags, notes | ✅ | ❌ |
| Saved-entry list with edit, add photos, delete | ✅ | ❌ |

The Android gaps are product behavior, not visual styling. Per the rule "design the behavior once, implement it natively on both", they need their own scheduled piece of work.

## Visual QA (2026-10-19)

Checked through the debug galleries, with a drawn fixture photo: `-MMRichQA room-photo|room-empty|room-moveout` on iOS, and `RichQAActivity --es case room-*` on Android.

| Case | iOS default | iOS AX3 | Android 1.0× | Android 2.0× |
|---|:-:|:-:|:-:|:-:|
| room-photo | ✅ | ✅ chips stack | ✅ | ✅ |
| room-empty | ✅ | ✅ | ✅ | ✅ |
| room-moveout | ✅ | — | ✅ | — |

Fixes made during QA:
- At AX3, the chips truncated ("4 pho…"). They now stack when they don't fit in a row.
- At large sizes, the mono time broke mid-value ("11:33 / AM"). It now drops under its label in one piece.

**Not yet verified:** the plate inside the live Room screen with real signed photos. That needs a signed-in session, and the emulator rebooted signed out.
