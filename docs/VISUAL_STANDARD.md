---
related-code:
  - "[[MoveMarkTheme.swift]]"
  - "[[MMTypography.kt]]"
  - "[[MMColors.kt]]"
  - "[[MMVaultProofHeroCard.swift]]"
  - "[[MMVaultProofHeroCard.kt]]"
  - "[[RoomEvidenceHero.swift]]"
  - "[[RoomEvidenceHero.kt]]"
domain: design-system
type: guide
status: wip
author: suren
tags: [movemark, design-system, visual-standard, ios, android]
---

# MoveMark Visual Standard: Editorial Evidence Archive

> **North star: MoveMark should make renters feel more protected every time they use it.** Every screen answers what MoveMark just helped the renter protect, prove, understand or preserve; every important action ends by showing what they gained ("3 photos recorded", "Case recorded", "Room compared", "Report ready"). Full bar, patterns, states and the seven review questions: [[MoveMark Design Standard]] (Obsidian vault, `MoveMark Product/`).

MoveMark should feel like a premium native app crossed with an editorial evidence archive. The goal is intentional composition, not more cards or more decoration. This standard applies to iOS and Android equally. iOS is the reference implementation, and Android matches its hierarchy, copy and states. The only differences allowed are platform conventions (back navigation, share sheet, permissions, system dialogs).

It builds on [[PRODUCT_DOCTRINE]]. Screen-level specs: [[ROOM_EVIDENCE_RECORD]]. Art-direction reference: Figma "MoveMark — Inspo V2". It is treated as the floor, not the ceiling.

## The rule

> **Design screens as compositions, not collections of components.**
> **Real evidence creates the atmosphere. The UI explains the evidence.**

Within two seconds, without reading, a user should feel what each screen means:

| Screen | Statement |
|---|---|
| Vault | My rental is documented. |
| Proof Sprint | This is what I still need. |
| Room | This evidence is preserved. |
| Reports | My proof has become a record. |
| Pro | This protects the whole rental lifecycle. |
| Account | Quiet utility. |

## Hierarchy (one hero per screen)

1. **Hero:** only one per screen.
2. **Important state:** coverage, current room, report readiness.
3. **Supporting information:** photos, records, issues.
4. **Metadata:** IDs, timestamps, counts.

If two things compete for level 1, one of them is wrong.

## Type: confident sans, restrained mono

| Voice | Use | iOS | Android |
|---|---|---|---|
| Sans | Everything: navigation, body, buttons, **and** large headings ("Your proof", "09 / 10", "Primary Bedroom", "Reports") | SF Pro (system) | system sans |
| Mono | Only where it proves authenticity: timestamps (`OCT 19 · 6:37 PM`), record IDs (`MM-RP-4C82`) | `monoMeta` | `FontFamily.Monospace` |

Kickers (`MOVE-IN EVIDENCE`, `RECORDED`) are small, tracked, uppercase sans. The editorial serif from the first rich pass is **retired**: screens drop it as they are redesigned. The Vault hero still uses it until the Proof redesign.

The interface should be readable from the hierarchy alone.

## Canonical references (locked 2026-10-19)

These are the visual target. They are art direction, not specs to trace: keep the composition, improve the details.

| Screen | Reference | What to take from it |
|---|---|---|
| Capture (room, camera) — **LOCKED 2026-10-26** | `testRoom*.png`, `testCameraChrome*.png` (supersedes `design-refs/room-dark-set.jpg`) | An empty room is a brief, not a blank: "No proof yet", what to capture before you unpack, one lime Take photos and a quiet Choose from Photos. The camera stays open for continuous capture: room name, live count, the next suggested shot, a thumbnail back to the room, lime Done. Pending photos can be removed before saving; the save bar is solid to the screen edge |
| Saved proof receipt — **LOCKED 2026-10-26** | `testReceipt*.png` | After every save, including a partial one: what the backend confirmed (photos, issues, time), "Source files preserved", "Recorded in your proof vault", the photo by itself, and one next step (next room, the report, or retry) |
| Proof — **LOCKED 2026-10-24** | `movemorkTests/__Snapshots__/VisualSnapshotTests/testProof*.png` (supersedes `design-refs/proof.jpg`) | A quiet dark header — the rental, its location and a thin move-in progress bar (never a captured photo: evidence lives only in its own clipped thumbnails) — then a bright working surface: the next room card holding the one capture action, one line of counts, a fixed-size recent-evidence strip with captions, one "rooms still need proof" row, next actions as a single vertical list |
| Root dock — **STANDARD 2026-10-26** | `movemork/Shared/MMProofTabBarV4.swift`; `testDock*.png` | One compact floating dock — Proof · Reports · Account — on the three root surfaces only (never on pushed screens, camera, receipt or modals). Active tab near-black with a short lime line under it, idle tabs grey; hidden while the keyboard is up; type capped at xxLarge. Root scroll views end with `MMSignedInScrollTailSpacer`, which reserves the dock's footprint, so content is never hidden under it |
| Maintenance — **LOCKED 2026-10-27** | `movemorkTests/__Snapshots__/MaintenanceCaseSnapshotTests/*.png` | A case archive, not a ticket queue: the log lists dated cases (photo, title, category · reported date, open/resolved, photo count) and stops; recording happens in its own focused sheet (+ in the header). A case reads MAINTENANCE CASE → title → REPORTED → one large evidence photo and strip → CASE TIMELINE from real events only (Case recorded, landlord follow-up, Repair pending/completed) → details → add to the record. The evidence viewer is image first with a quiet record bar (phase, room · entry, recorded time, condition, tags, notes) |
| Move-out — **LOCKED 2026-10-27** | `movemorkTests/__Snapshots__/MoveOutSnapshotTests/*.png` | Truth first: MOVE-OUT header with move-out proof progress, then a tally (changed · need proof · unchanged). Changed and new-issue rooms are inspection spreads: state, room, what changed in record language, MOVE-IN · date and MOVE-OUT · date above large photos side by side, the move-out note. The next room still needing proof is a card with its move-in photo and the one lime capture action; the rest are quiet rows. Unchanged rooms are compact and expand to the pair. Quiet closeout checklist; the report appears only once every room is compared. No fault, severity, AI judgement or celebration |
| Rental record — **LOCKED 2026-10-27** | `movemorkTests/__Snapshots__/RentalRecordSnapshotTests/*.png` | The master file for one rental: RENTAL RECORD header (address, unit · city, moved in, move-in proof line), then Rooms (next room holds the one lime action; all documented → Generate move-in report), Records (lease, deposit receipt, listing proof: added date and file, or Needed and why), Maintenance, Move-out only when relevant, Rental details last. No feature directory rows (case builder, exports) and no proof trail |
| Entry + first run — **LOCKED 2026-10-27** | `movemorkTests/__Snapshots__/AuthScreenSnapshotTests/*.png` | Welcome: "Prove what was already there.", a Proof Slip previewing the outcome, lime Start move-in proof, I already have a vault, one trust line. Calm sign in / create vault (no reset path while email is deferred; a Check your email state). First run: two paths, address-first rental setup, straight into the first room's proof. Load failure keeps the proof's safety in the copy and offers retry and sign out |
| Evidence sheets — **LOCKED 2026-10-27** | `movemorkTests/__Snapshots__/SheetsPaywallSnapshotTests/testEditEvidence*.png`, `testAddPhotos*.png`, `testEditName*.png` | Edit evidence leads with the record (room · stage, recorded time, the real photo), then condition, what was observed, notes; lime Save changes with a quiet red Delete evidence beneath behind the native confirmation. Add photos: one Choose from Photos, a pending grid, lime Add to evidence only once photos are chosen. Edit name stays boring: field, one line, Save |
| Paywall — **LOCKED 2026-10-27** | `movemorkTests/__Snapshots__/SheetsPaywallSnapshotTests/testPaywall*.png` | Dark full screen: MOVEMARK PRO, "Protect the full rental timeline.", why it opened, the rental timeline (move-in recorded, maintenance, move-out with Move-out report · Pro, if questioned with Evidence packet · Pro), "Free keeps the record. Pro turns it into the reports and evidence packet you'd use." The pinned bar carries only the App Store price (yearly, with RevenueCat's per-month figure), lime Continue with Pro and "Cancel anytime · Managed by Apple"; the other plan, Restore and Not now sit below the fold (Continue on Free stays pinned when plans fail to load). Prices only from StoreKit |
| Reports — **LOCKED 2026-10-26** | `movemorkTests/__Snapshots__/VisualSnapshotTests/testReports*.png` (supersedes `design-refs/reports.jpg`) | A document control centre, not an export list: the Vault's dark header (MoveMark · REPORTS · Your proof records), then one primary artifact — the move-in report: rental, rooms documented, counts, one readable state (needs room proof / needs one record / not generated / generating / ready / couldn't generate) and lime only on its single action (View report, with Share quiet beneath). A quiet vertical history (date · state, share or retry inline), then move-out and dispute as quiet rows. No fake PDF previews: a plain document mark; the PDF opens in the native preview from a local, authenticated download |
| Account — **LOCKED 2026-10-26** | `movemorkTests/__Snapshots__/VisualSnapshotTests/testAccount*.png`, `testDeleteAccount*.png` (supersedes `design-refs/account.jpg`) | Calm native settings: the shared dark header (MoveMark · ACCOUNT · Your account), then plain identity (email, plan — a lime dot only for Pro, from the RevenueCat entitlement) and grouped native rows: MoveMark (name, subscription, restore with its result beneath), Support, Legal. Sign out neutral; Delete account apart in calm red, behind an explanation and a final confirmation. Only controls that work: no password or email-verification rows until a domain exists |

Ignore the travel and plant boards: they were exploration and drifted generic.

**Corrections to the references:** the lime CTA moves to MoveMark green (no fitness-app lime); the coverage pill gets slimmer; on Reports the record ID and generated time get more weight because they are provenance; mockup people and stock photos never ship; the renter's evidence, or a designed empty state, takes their place.

**One system, different compositions:** photographic rental evidence on top, clean Apple-like utility underneath. Screens share type, radii, spacing and green; they do not share a layout.

## Evidence integrity (rule)

Evidence photography may dominate the UI, but **MoveMark never beautifies, enhances, generatively modifies, replaces or destructively crops original evidence.** No automatic border removal, no filters, no AI fill.

- Thumbnails and heroes may use standard aspect-fill framing (a display crop only).
- Opening a photo always shows the untouched original, uncropped (`RoomPhotoViewer` uses aspect-fit).
- Placeholders for missing evidence must never resemble evidence, and never appear in an evidence section ("Recent evidence" shows only saved photos; rooms without proof are listed separately).
- Generated or stock imagery is allowed only in debug and test fixtures, never in a user's record.


## Consistency rules (pass of 2026-10-27)

- **Record headers** (overview screens): MoveMark wordmark, then EYEBROW = what the screen is, then the title = its subject (usually the rental), then one or two quiet lines. YOUR PROOF / RENTAL RECORD / ROOMS / MAINTENANCE / MOVE-OUT · 88 Harbour St. Detail screens drop the wordmark (MAINTENANCE CASE · Water leak under sink).
- **Focused-flow headers** (sign in, first run, load failure): wordmark, title, one line. No eyebrow.
- **Progress** lives in the dark header as the lime line: label and %, the line, then the count. It never appears as a second bar on the light sheet.
- **Overview screens summarise; they don't repeat other screens.** No feature-directory rows, and no "supporting proof" lists on Rooms.
- **Choice chips wrap** (FlowLayout). They never scroll sideways off the edge.
- **Light-sheet field labels** are sentence case ("Room name", "Your name"). Uppercase is only for section labels on dark evidence surfaces (CONDITION, WHAT WAS OBSERVED).
- **One evidence vocabulary everywhere.** Condition chips run best → worst; "What was observed" (never "Issue tags" or "Damage noted"); Label and Notes. "Move-out proof needed" (never "missing"). Recorded is the time MoveMark received a photo; Captured is only a source's own declared time.
- **Refresh failures are calm.** Use the info notice, say what failed and that the saved record is still here, and offer Try again. No red alarm for a refresh.
- **The same task gets the same sheet.** Both add-room sheets use one line, the field and wrapping suggestion chips.

## Material and color

| Role | Value |
|---|---|
| Evidence surfaces (Room, the Proof hero, the Reports artifact card) | Deep near-black, so the photo carries the screen |
| Working surfaces (Proof body, Reports list, Account, documents) | Light: warm white / ivory with grouped rows, in the Apple settings idiom |
| Accent | MoveMark green: the primary next action, active state, Ready. **At most one green call to action per screen.** A documented room's "Add evidence" is a white pill, not green. |
| Warning | Muted amber |

**Glass and translucency are allowed only where a control sits over evidence:** the floating dock, capture controls, metadata chips over photos, and View / Share over a report preview. A glass control should feel like it sits above the evidence, not like another card.

## Composition

Prefer full-width sections, large editorial figures, photo crops, thin dividers, grouped rows, compact metadata pills and bottom sheets. Avoid stacking card after card after card.

**User photos are visual material, not attachments.** When a room or rental has evidence, its photo carries the composition. Never use stock or decorative imagery in place of the user's evidence.

**Room stays dark**, because evidence is viewed like a photo library. Proof and Reports are a dark photographic object over a light working surface. Account is light throughout.

**Sophistication comes from contrast.** Vault and Room can feel substantial; Reports feels formal; Account stays restrained. Don't make every screen a statement piece.

## Motion

Motion should be slow, physical and intentional, and it must respect reduce-motion. Nothing bounces. Heroes respond to scroll: a pull stretches the photo, scrolling up drifts it slower than the content (parallax), and the title settles into the navigation bar once the hero leaves.

## Rollout order

Each screen is designed once, built natively on both platforms, and checked on devices before the next one starts.

1. **Room**: in progress, see [[ROOM_EVIDENCE_RECORD]]
2. Vault (evidence-photo atmosphere behind the property header)
3. Reports (the latest record shown as a physical document; minimal archive rows)
4. Pro (lifecycle story first: move in, live there, move out, dispute; features second)
5. Onboarding (one atmospheric composition, "Prove what was already there.", large bottom call to action)
6. Account (grouped sections, minimal green: the calmest screen)
