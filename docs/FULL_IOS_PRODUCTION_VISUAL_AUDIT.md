# MoveMark — Full iOS Production Visual Audit

Status: active implementation plan  
Branch: `design/full-production-redesign`  
Base: `recovery/neon-ios@3764a20`

## Goal

Finish the **entire first-party iOS visual system** to the same production bar as the locked core.

The core visual language is already established:

- evidence-first, calm, native, professional
- text-only `MoveMark` branding in-product
- deep near-black evidence/header surfaces
- warm/light working surfaces
- restrained lime as signal, normally at most one primary lime action per screen
- real renter evidence is the visual material
- no generic SaaS dashboard treatment
- no card grid as a default composition
- no glow, decorative gradients, stock evidence, or fake progress
- truthful saved/loading/error states
- small-device + largest Dynamic Type coverage
- physical-device verification where interaction matters

## Locked surfaces — do not structurally redesign

These remain locked unless a real usability/production bug is found.

| Surface | Primary implementation | Status |
|---|---|---|
| Proof / Vault | `Features/Vault/ProofHomeView.swift`, `VaultRootView.swift` | LOCKED |
| Room brief / capture flow | `Features/Evidence/EvidenceCaptureView*.swift` | LOCKED |
| Continuous camera | `Features/Evidence/CameraCaptureView.swift` | LOCKED |
| Saved Proof Receipt | `Features/Evidence/SavedRoomReceipt.swift` | LOCKED |
| Populated room evidence composition | `Features/Evidence/Components/RoomEvidence*.swift` | LOCKED except real bugs |
| Reports root | `Features/Export/ReportsHomeView.swift` | LOCKED |
| Account root + deletion | `Features/Account/AccountHomeView.swift`, `DeleteAccountView.swift` | LOCKED |
| Shared root dock | `Shared/MMProofTabBarV4.swift` | STANDARD / LOCKED |

## Production audit matrix

### P0 — finish first

| Area | Implementation | Current issue | Target |
|---|---|---|---|
| Maintenance log | `Features/Maintenance/MaintenanceLogView.swift` | Card-stack composition; maintenance reads as a form/list rather than a case record. Multiple pills/cards compete for hierarchy. | **Case-file composition**: one current incident / next action, evidence count, status, quiet chronological rows. |
| Maintenance issue detail | `Features/Maintenance/MaintenanceIssueDetailView.swift` | Overview/timeline/evidence/follow-up are separate generic cards. | **Case Card + Timeline Row + Evidence Tile**. Issue is the hero, chronology is the spine, evidence is photographic. |
| Move-out | `Features/MoveOut/MoveOutFoundationView.swift` | Current “defense summary” + checklist + repeated MMCard before/after blocks is functionally correct but visually generic and card-heavy. | **Before → after comparison** is the hero. Paired move-in / move-out evidence, condition delta, completion strip, quiet closeout checklist. |
| Supporting-record entry points | current property/evidence routes | Lease/deposit/listing flows need one shared proof-record language rather than unrelated upload controls. | **Supporting Record Row / Proof Slip**: type, added date, status, one action. |
| Dispute builder | route/implementation to trace before edit; behavior documented in `docs/DISPUTE_BUILDER_PLAN.md` | Functional case setup/evidence selection exists in product plan but has not been brought into the locked visual system. | **Case builder**: claim → selected proof → timeline/context → packet readiness → generate packet. No legal-advice styling. |

### P1 — complete product shell

| Area | Implementation | Current issue | Target |
|---|---|---|---|
| Add rental | `Features/Property/NewPropertyView.swift` | Repeated `MMCard` wrappers around form groups; feels like component stack. | Native editorial form: one intro, grouped fields, clear required hierarchy, one Save action. |
| Edit rental | `Features/Property/EditPropertyView.swift` | Same repeated-card form composition. | Match Add Rental; calm native edit sheet. |
| Room list / Proof Sprint | `Features/Rooms/RoomListView.swift` | Rich proof styling exists but needs audit against the now-locked Vault/Capture vocabulary and dock-era hierarchy. | Evidence queue: room name, proof state/count, clear next room. No competing progress systems. |
| Welcome | `Features/Welcome/WelcomeScreen.swift` + welcome components | Advanced composition already exists; must be checked against current text-only branding, current lime, and final proof-slip language. | “Prove what was already there.” One proof artifact, one CTA, premium native entrance, no marketing-site feel. |
| Auth | `Features/Auth/AuthContainerView.swift` | Contains image logo + text lockup and multiple translucent card surfaces; inconsistent with text-only in-product branding and calmer production system. | Minimal native auth surface, text-only MoveMark, one form surface, privacy-safe errors, no fake email-reset affordances. |
| First run | `Features/FirstRun/*.swift` | Separate property/room/proof setup surfaces risk drifting from the final Vault/Capture system. | First run should feel like entering the real product, not a separate onboarding theme. |
| Paywall | `Features/Paywall/ProPaywallView.swift` | Visually busy: multiple cards, gradient surface, many green accents, pricing-option cards. | Lifecycle story first, features second, restrained price selection, one purchase CTA, native Restore Purchases. |

### P2 — consistency and state coverage

| Area | Files/components | Requirement |
|---|---|---|
| Evidence/photo viewer | `RoomPhotoViewer.swift`, shared image components | Original always aspect-fit; metadata quiet; no destructive display assumptions. |
| Custom loading/error/empty states | `MMEmptyState.swift`, `MMLoadingState.swift`, `MMErrorBanner.swift`, feature-specific states | Match final dark/light context and truthful retry behavior. |
| Sheets and custom modals | property/room/auth/paywall flows | Native hierarchy, correct safe areas, no legacy bright green or old card chrome. |
| Typography | Theme + all feature screens | Retire old serif/legacy hero styles anywhere still visible; sans hierarchy, mono only for provenance. |
| Status bars | all root/pushed dark headers | Solid readable top band; no content running under clock. |
| Bottom spacing | all root tabs | Root content must clear `MMSignedInScrollTailSpacer` / dock footprint. |
| Dynamic Type | all first-party screens | Small iPhone + largest supported Dynamic Type, no clipping, primary action reachable. |
| VoiceOver / tap targets | all controls | 44pt targets, sensible labels, no hidden semantic state. |

## Canonical reusable visual vocabulary

Use these concepts deliberately rather than defaulting to `MMCard` everywhere:

### Proof Slip
Use for a recorded/official artifact:
- saved proof receipt
- supporting records
- generated report metadata
- provenance moments

### Evidence Tile
Use for:
- renter photos
- room evidence
- maintenance evidence
- move-in / move-out paired evidence

### Case Card
Use sparingly for one case-level object:
- maintenance incident
- dispute claim

A Case Card is not a generic container. It must represent a real case/object.

### Timeline Row
Use for chronological facts:
- maintenance reported/responded/resolved
- dispute chronology
- evidence record history

### Progress Strip
Use for completion:
- move-in room completion
- move-out room completion
- packet/readiness only where underlying state is real

## Screen-specific target compositions

### Maintenance
1. Dark evidence/case header: issue + status + discovered date
2. Evidence strip
3. Timeline as the central content spine
4. Follow-up / landlord response
5. Resolve action
6. History/list uses concise case rows, not repeated large cards

### Move-out
1. Rental / move-out completion header
2. Primary before-vs-after comparison
3. Room rows ordered by missing move-out proof first
4. Condition delta visible but restrained
5. Closeout checklist below evidence, not competing with it
6. Generate move-out artifact when ready

### Dispute builder
1. Case identity: dispute type, title, amount
2. Claim / summary
3. Selected supporting proof
4. Maintenance / room / document evidence grouped by provenance
5. Readiness as restrained supporting state, not gamification
6. Save draft
7. Generate packet

### Rental setup
1. One title + short purpose line
2. Native grouped inputs
3. Address fields should never display/persist placeholder “Unknown”
4. One primary Save/Create action
5. Validation adjacent to the field/problem, not a generic top error where avoidable

### Auth
1. Text-only MoveMark
2. Sign in / create private vault
3. Minimal input surface
4. Privacy-safe combined invalid-credential error
5. No password-reset UI until production email/domain exists
6. Terms/privacy remain quiet footer links

### Paywall
1. MoveMark Pro + lifecycle value
2. Move in → live there → move out → dispute
3. Concrete Pro value, no inflated marketing claims
4. Monthly/annual choice
5. One purchase CTA
6. Restore purchases + legal pricing copy
7. Report-pack purchase remains separate/secondary if enabled

## Implementation status — current design branch

| Surface | Implementation state | Visual sign-off |
|---|---|---|
| Proof / Vault | Existing locked production design unchanged | LOCKED |
| Capture + camera + Saved Proof Receipt | Existing locked production design unchanged | LOCKED |
| Reports root | Existing locked production design unchanged | LOCKED |
| Account root | Existing locked production design unchanged | LOCKED |
| Floating dock | Existing shared navigation unchanged | LOCKED |
| Maintenance log | Rebuilt as active case + quiet case rows | **Needs simulator/iPhone screenshot review** |
| Maintenance issue detail | Rebuilt around case hero → evidence → timeline → follow-up → resolution | **Needs simulator/iPhone screenshot review** |
| Move-out foundation | Rebuilt as move-in/move-out comparison record, missing rooms first | **Needs simulator/iPhone screenshot review** |
| Add rental | Rebuilt as one native grouped form | **Needs simulator screenshot review** |
| Edit rental | Aligned with Add Rental; placeholder location values suppressed | **Needs simulator screenshot review** |
| Rental workspace | Duplicate progress/timeline layers removed; supporting records + lifecycle actions simplified | **Needs simulator/iPhone screenshot review** |
| Room list / walkthrough | “Proof Sprint” removed; now a move-in evidence queue with one progress model | **Needs simulator/iPhone screenshot review** |
| Add Room sheet | Legacy green-selected chips removed | **Needs simulator screenshot review** |
| Auth | Text-only MoveMark, one calm form, no dead password-reset affordance | **Needs simulator/iPhone screenshot review** |
| First-run rental setup | Card wrapper removed; now enters the same product language | **Needs simulator screenshot review** |
| First-run room/moment choice | Selected treatment and icon accents restrained | **Needs simulator screenshot review** |
| First-run saved receipt | Reuses locked Proof Receipt | LOCKED BY REUSE |
| Welcome | Existing editorial evidence-artifact composition passes code audit; no redesign-for-redesign change made | **Needs final route-tour confirmation only** |
| Full-screen evidence viewer | Aspect-fit full evidence, internal signed URL, display-only thumbnail crops | PASS — no visual change required |
| Shared loading/error/empty components | Existing system retained to avoid invalidating locked screens without a usability bug | PASS — no global rewrite |
| Backend-misconfiguration screen | Production developer setup instructions removed; technical detail DEBUG-only | **Needs simulator error-state check** |
| Paywall | Lifecycle-first hierarchy, quieter plan selection, no gradient/glow card stack; release RevenueCat debug copy removed | **Needs StoreKit/simulator/iPhone review** |
| Dispute Builder | **No dedicated native route/view exists in current codebase**. Documentation describes an older v1 implementation, but current native app routes Case Builder to Reports. | PRODUCT GAP — do not pretend complete |

### Reachability / dead-code notes

- `EvidenceSavedProofSection` is an older card-heavy evidence component, but the current room flow uses `RoomEvidenceBody` + `RoomPhotoViewer`; it is not part of the active capture composition.
- `OnboardingNameScreen` is not part of the current first-run path; first-run name capture happens inside `FirstRunPropertySetupView`.
- Native system surfaces remain native: camera permission alerts, share sheet, Quick Look/PDF preview, Photos picker, and Apple subscription management.

### CI note

The previous iOS workflow used `macos-15`, which cannot correctly compile the app's iOS 26.2 / current Swift syntax. The design branch updates iOS CI to GitHub's GA `macos-26` runner. This workflow change must be validated before merging.

## Production acceptance criteria for every redesigned screen

A screen is not “done” because it compiles.

Before locking:
- normal state visually inspected
- empty state
- loading state where applicable
- real error/retry state
- small iPhone snapshot
- largest Dynamic Type snapshot
- status-bar/safe-area inspection
- bottom/dock clearance where applicable
- VoiceOver/tap-target sanity
- production data semantics preserved
- physical-device verification for camera, photos, sharing, billing, destructive actions, or other hardware/system integrations
- no legacy shield lockup / fluorescent green / obsolete typography / generic card-stack composition
- tests green
- screenshot/reference added to visual standard
- then LOCK the screen

## Execution order

1. Maintenance log + issue detail
2. Move-out before/after
3. Dispute builder
4. Supporting records / evidence viewer
5. Add/Edit rental + room list
6. Welcome/Auth/First Run
7. Paywall/billing surfaces
8. Global state/sheet/error consistency sweep
9. Full iPhone visual route tour
10. Android parity pass using the final iOS hierarchy and states

## Scope guard

This pass changes **visual composition and interaction clarity**, not backend architecture or feature scope.

Do not:
- add unrelated features
- alter evidence integrity rules
- change export/report contracts
- weaken security
- resurrect React Native
- invent email/reset functionality before the domain exists

