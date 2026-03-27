# Dispute Builder — Build summary

## Current state (v1)

### Done
- **Case setup** — Dispute type picker (Deposit withheld, Cleaning fee, False damage, Other), case title, amount in question, summary, move-out date, “Received itemized charges” toggle, charge date (when itemized). All bound to local state; **dispute type** maps to DB enum: `deposit_withheld`, `cleaning_fee`, **`damage_charge`** (schema uses this, not `false_damage`), `other`.
- **Evidence selection** — Room photos (evidence_files), maintenance issues, supporting documents. Disclosure groups with checkmarks; **selected IDs** stored in `selectedEvidenceFileIds`, `selectedMaintenanceIds`, `selectedDocumentIds`. Data loaded via `loadEvidenceData()` (fetchEvidenceFiles, fetchIssues, fetchDocuments).
- **Packet strength** — Readiness pill (Not ready / Record building / Good support / Strong support), FactChips for photo/issue/doc counts, summary rows for type/amount/itemized.
- **Save draft** — Builds `DisputeRow` (id, propertyId, userId, title, disputeType, status "draft", amountInQuestion, summary), **upsertDispute**, then **replaceEvidenceLinks** (delete existing links, insert current selections). Sets `disputeId` for later export.
- **Load draft** — On open (in `.task` after `loadEvidenceData`), **fetchDraft(propertyId, userId)** loads latest draft by status = "draft" and **fetchEvidenceLinks(disputeId)** loads linked IDs; form and selection sets are **pre-populated** (title, amount, summary, type, and the three selected-ID sets).
- **Export** — “Save draft” (above). “Export simple PDF”: `PDFGenerator.generateDisputeSummary`, upload to storage, insert export row, share. “Generate formal packet”: requires saved draft, calls **callGenerateDisputePacket** (Supabase function), inserts export record, share. Both can set `openExportsOnShareDismiss` to navigate to Export History on share dismiss.

### Repository
- **DisputeRepository**: `upsertDispute`, **fetchDraft(propertyId:userId:)**, **fetchEvidenceLinks(disputeId:)**, `replaceEvidenceLinks`, `insertEvidenceLinks`, `insertExportRecord`, `callGenerateDisputePacket`.
- **dispute_evidence_links**: One row per selected item (evidence_file_id OR maintenance_issue_id OR property_document_id). Replace = delete by dispute_id, then insert new set.

### Dispute schema (move-out / charge fields)
- **move_out_date**, **received_itemized**, **charge_date** are on `DisputeRow` and persisted: Save draft includes them (move-out date and charge date as `yyyy-MM-dd`; charge date only when `receivedItemized` is true). **loadDraftIfNeeded** restores them. **PDFGenerator.generateDisputeSummary** accepts optional `moveOutDate`, `receivedItemized`, `chargeDate` and renders them on the cover page (Move-out date, Itemized charges received, Charge date). Migration **20260313000002_disputes_move_out_fields.sql** adds the three columns if missing.

### Later
- Export history polish; formal packet edge-function reliability.
