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
| Room | `design-refs/room-dark-set.jpg` (screens 2, 3, 6, 7) | The renter's photo as the poster: near edge-to-edge, chips and title layered on it, compact glass controls, a "2 of 4" viewer with filmstrip, a calm capture surface when empty |
| Proof | `design-refs/proof.jpg` | The rental photo as a tall editorial hero with a floating coverage pill, then a bright working surface: next room, one capture action, quiet stats, recent evidence, next actions |
| Reports | `design-refs/reports.jpg` | The report as a physical, tilted document inside a dark photographic card; Ready state, record ID and generated time prominent; move-out and dispute quiet below |
| Account | `design-refs/account.jpg` | Native grouped settings, one Pro block with personality, nothing decorative |

Ignore the travel and plant boards: they were exploration and drifted generic.

**Corrections to the references:** the lime CTA moves to MoveMark green (no fitness-app lime); the coverage pill gets slimmer; on Reports the record ID and generated time get more weight because they are provenance; mockup people and stock photos never ship; the renter's evidence, or a designed empty state, takes their place.

**One system, different compositions:** photographic rental evidence on top, clean Apple-like utility underneath. Screens share type, radii, spacing and green; they do not share a layout.

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
