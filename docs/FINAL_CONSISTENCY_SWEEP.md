# Final consistency sweep — user-facing errors (closed)

**Goal:** No raw backend strings in UI; distinguish save vs upload vs refresh; one mapper layer.

## Hub

- **`MoveMarkFlowMessage`** — flow-specific copy + `UserFacingDatabaseError` for auth/storage/RLS/network.
- **`UserFacingDatabaseError`** — pattern match on `localizedDescription` (internal only).

## Local state strings (not from `Error`)

Defined on `MoveMarkFlowMessage`: `signInRequired`, `noActiveProperty`, `notSignedInPropertyForm`, `notSignedInShort`, `noPropertyOrAuth`, `maintenanceIssueNotFound`.

## Definition of done (this repo pass)

- [x] Dispute draft / PDF / packet / evidence load → `MoveMarkFlowMessage`
- [x] Auth / account / onboarding → mapped (no raw Supabase copy in UI)
- [x] Property list / switch / create / update / add room → mapped
- [x] Export verify / share / list / local file verify → mapped
- [x] Move-out checklist + client PDF export → `moveOutChecklistSaveFailed` / `moveOutReportExportFailed`
- [x] Room evidence / maintenance / vault docs → prior pass (outcomes + soft notices)
- [x] Straggler grep: `errorMessage =` either validation, mapper, or shared constant

## Maintenance

Re-run occasionally:

```bash
rg "errorMessage\\s*=" movemork/movemork --glob '*.swift'
rg "localizedDescription" movemork/movemork --glob '*.swift'
rg "MMErrorBanner\\(" movemork/movemork --glob '*.swift'
```

Expect `localizedDescription` only inside mappers, `#if DEBUG` prints, or StoreKit/subscription logging.

## Deferred (optional)

- DTO/schema contract audit vs Supabase
- Further PDF/export pipeline hardening on API side
