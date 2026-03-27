# Loading / Error / Empty State Consistency

Sprint 3 — Standard patterns for reliable, shippable UX.

## Shared components

- **MMErrorBanner** — Error message with optional "Try again" action. Use for any user-facing error (validation, network, save failure). Icon: exclamationmark.triangle.fill (orange).
- **MMLoadingState** — Full-screen loading with message. Use for initial data load (e.g. proof trail, exports).
- **MMCopy** — Standard strings: `loadingProofTrail`, `loading`, `saving`, `genericError`, `tryAgain`.

## Where they’re used

| Screen | Loading | Error | Empty |
|--------|--------|-------|--------|
| Vault root | MMLoadingState(loadingProofTrail) | MMErrorBanner + retry | No property card + Add property |
| Home (legacy) | MMLoadingState | MMErrorBanner + retry | Same |
| Add Property | Button spinner + disabled | MMErrorBanner | N/A |
| Edit Property | Button spinner | MMErrorBanner | N/A |
| Property Vault | — | MMErrorBanner + retry (photo/file upload) | — |
| Walkthrough | — | MMErrorBanner + retry (add room / move-in export) | No rooms card + Add room above |
| Room Detail | Button "Saving proof…" + dim | MMErrorBanner + retry | Saved section can be empty (hero shows placeholder) |
| Supporting docs | Inline in Vault | MMErrorBanner + retry | Per-type "Not uploaded yet" |
| Maintenance | ProgressView when loading list | MMErrorBanner + retry (add incident) | "No incidents yet" card when list empty |
| Maintenance detail | Button spinners | MMErrorBanner + retry (follow-up/resolve/photos) | — |
| Move-out | ProgressView (checklist) | MMErrorBanner + retry (checklist or export) | "No rooms yet" when rooms empty |
| Dispute Builder | Progress when loading evidence | MMErrorBanner + retry (load/save/export) | Empty property + section empty texts |
| Exports | ProgressView | MMErrorBanner + retry | "No exports yet" card |
| Account | Reset button spinner | MMErrorBanner (reset, edit name) | — |
| Onboarding | Button spinner | MMErrorBanner | N/A |

## Rules

1. **Errors** — Use MMErrorBanner. For load failures where retry makes sense, pass `retryTitle` and `onRetry`.
2. **Full-screen load** — Use MMLoadingState with a message (e.g. MMCopy.loadingProofTrail).
3. **Button load** — Disable primary button, show "Saving…" / "Adding…" / "Exporting…", optional ProgressView on or beside button.
4. **Empty** — When a list or section has no data, show a short card: title + one line of explanation + optional CTA (e.g. "Add room above").
5. **Copy** — Prefer MMCopy for shared strings. Keep error messages specific where possible; use MMCopy.genericError only as fallback.
6. **Retry** — Where a failure is recoverable (network, save, export), show "Try again" and re-run the same operation. See below.

## Retry behavior (Sprint 3 Item 12)

| Flow | Retry action |
|------|----------------|
| Evidence save (Room Detail / move-out) | Re-run saveEvidence(); form content kept. |
| Document photo upload (Vault) | Re-run upload with same selection if still present; otherwise retry clears error. |
| Document file upload (Vault) | "Try again" reopens file picker for same doc type. |
| Maintenance: add incident | Re-run addIncident(); form (title, details, photos) preserved. |
| Maintenance detail: follow-up / resolve / photos | Retry re-runs same action; follow-up note preserved on failure. |
| Move-out: checklist load/save | Retry re-runs loadChecklist(). |
| Move-out: export | Retry re-runs exportMoveOutReport(). |
| Walkthrough: add room | Retry re-runs submitAddRoom(); room name preserved (cleared only on success). |
| Walkthrough: move-in export | Retry re-runs exportMoveInReport(). |
| Dispute Builder: load evidence | Retry re-runs loadEvidenceData(). |
| Dispute Builder: save draft | Retry re-runs saveDraft(); form preserved. |
| Dispute Builder: simple PDF / formal packet | Retry re-runs same export. |
| Export History: load list | Retry re-runs loadExports(). |

**Form text preservation:** Add Property, Edit Property, Room Detail, Maintenance composer, Dispute Builder, and Walkthrough add-room do not clear form fields on save/export failure; fields are cleared only on success (or when the user dismisses).
