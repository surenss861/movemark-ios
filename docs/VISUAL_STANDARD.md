---
related-code:
  - "[[MoveMarkTheme.swift]]"
  - "[[MMTypography.kt]]"
  - "[[MMColors.kt]]"
  - "[[MMVaultProofHeroCard.swift]]"
  - "[[MMVaultProofHeroCard.kt]]"
  - "[[MMRoomEvidencePlate.swift]]"
  - "[[MMRoomEvidencePlate.kt]]"
domain: design-system
type: guide
status: wip
author: suren
tags: [movemark, design-system, visual-standard, ios, android]
---

# MoveMark Visual Standard: Editorial Evidence Archive

MoveMark should feel like a premium native app crossed with an editorial evidence archive. The goal is intentional composition, not more cards or more decoration. This standard applies to iOS and Android equally. iOS is the reference implementation, and Android matches its hierarchy, copy and states. The only differences allowed are platform conventions (back navigation, share sheet, permissions, system dialogs).

It builds on [[PRODUCT_DOCTRINE]]. Screen-level specs: [[ROOM_EVIDENCE_RECORD]].

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

## Three type voices

| Voice | Use | iOS | Android |
|---|---|---|---|
| Sans | Navigation, buttons, body copy | system | system |
| Editorial serif | Property identity, room names, major counts, report titles | `editorialTitle`, `coverageFigure`, `statFigure` | `FontFamily.Serif` |
| Mono | Timestamps, report IDs, photo IDs, file metadata, generated dates | `monoMeta` | `FontFamily.Monospace` |

Kickers (`MOVE-IN COVERAGE`, `RECORDED`) are small, tracked, uppercase sans.

## Material and color

| Role | Value |
|---|---|
| Background | Deep near-black / dark green |
| Primary surface | Soft charcoal / green-black, near-neutral (green is a signal, not a surface) |
| Evidence paper | Warm ivory, for formal records (report covers) only |
| Accent | MoveMark green: attention, action, active state. **At most one green call to action per screen.** |
| Warning | Muted amber |

**Glass and translucency are allowed only where a control sits over evidence:** the floating dock, capture controls, metadata chips over photos, and View / Share over a report preview. A glass control should feel like it sits above the evidence, not like another card.

## Composition

Prefer full-width sections, large editorial figures, photo crops, thin dividers, grouped rows, compact metadata pills and bottom sheets. Avoid stacking card after card after card.

**User photos are visual material, not attachments.** When a room or rental has evidence, its photo carries the composition. Never use stock or decorative imagery in place of the user's evidence.

**Sophistication comes from contrast.** Vault and Room can feel substantial; Reports feels formal; Account stays restrained. Don't make every screen a statement piece.

## Motion

Motion should be slow, physical and intentional, and it must respect reduce-motion. Nothing bounces.

## Rollout order

Each screen is designed once, built natively on both platforms, and checked on devices before the next one starts.

1. **Room**: in progress, see [[ROOM_EVIDENCE_RECORD]]
2. Vault (evidence-photo atmosphere behind the property header)
3. Reports (the latest record shown as a physical document; minimal archive rows)
4. Pro (lifecycle story first: move in, live there, move out, dispute; features second)
5. Onboarding (one atmospheric composition, "Prove what was already there.", large bottom call to action)
6. Account (grouped sections, minimal green: the calmest screen)
