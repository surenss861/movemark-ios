# Maintenance — Build summary

## Current state (v1)

### Done
- **MaintenanceLogView** — Inline “Log incident” form: title, **fixed category picker** (MaintenanceCategory), details, photo picker, “Save incident”. Open vs Resolved sections; tap issue → Issue Detail. List loads from `maintenanceRepo.fetchIssues(propertyId:)` on appear and after save. **Validation:** title required (“Enter an issue title.”).
- **MaintenanceCategory** — Enum in MaintenanceRepository: Water damage, Heating / cooling, Pest, Appliance, Structural, Plumbing, Electrical, Other. Single selection via horizontal scroll of pills.
- **PropertyStore.addMaintenance** — Builds `MaintenanceIssueRow` with **dateDiscovered** and **dateReported** (both set to now), inserts via `maintenanceRepo.insertIssue`, uploads photos to `maintenance-media`, links via `inspectionRepo.insertEvidenceFile(..., maintenanceIssueId:)`. Then calls **`refreshMaintenance(propertyId:)`** so `maintenanceLog` is updated from DB.
- **PropertyStore.refreshMaintenance(propertyId:)** — Fetches issues and maps to `MaintenanceRecord`; updates `maintenanceLog` for Dispute Builder and other consumers.
- **MaintenanceIssueDetailView** — Loads issue by id (from container). Overview (category, status, description, discovered/reported/response/follow-up), timeline, evidence (signed URLs from `evidence_files`), follow-up card (landlord response note + “Save follow-up”), “Mark resolved”. **Save follow-up** → `maintenanceRepo.updateFollowUp(id:note:)`. **Mark resolved** → `maintenanceRepo.markResolved(id:)`. **Attach more photos** → upload to storage + `insertEvidenceFile(..., maintenanceIssueId:)` then reload evidence.
- **MaintenanceIssueDetailContainerView** — Resolves issue by ID from `propertyStore.currentProperty` + `repo.fetchIssues`, then shows `MaintenanceIssueDetailView(issue:)` or error/loading.

### Flow
1. User opens Maintenance → list from `loadIssues()` (API). Composer: title, category, details, photos → “Save incident” → `propertyStore.addMaintenance` → insert row, upload photos, `refreshMaintenance` → form clears, `loadIssues()` runs → list shows new issue.
2. Tap issue → push to Issue Detail (container loads issue by id) → overview, timeline, evidence, follow-up, resolve. Save follow-up / Mark resolved updates DB; local `@State issue` is updated so UI reflects change. Back → list still shows old data until next `onAppear`/reload (list reloads on appear).

### Repository
- **MaintenanceRepository**: `fetchIssues`, `insertIssue`, `markResolved`, `updateFollowUp`, `uploadAttachment`.
- **InspectionRepository**: `insertEvidenceFile` (with `maintenanceIssueId`), `fetchEvidenceFilesByMaintenanceIssue`, `signedURL(bucket:path:)` for evidence thumbnails.

### Later
- List from store: have Maintenance log use `propertyStore.maintenanceLog` and drop local `loadIssues()` for single source of truth (would require mapping `MaintenanceRecord` to list row display).
- Refresh list when returning from detail (e.g. after resolve) without full reload.
- Photo count in list/overview from `evidence_files` per issue.
