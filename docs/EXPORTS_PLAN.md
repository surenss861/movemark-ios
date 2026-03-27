# Exports & output reliability — Build summary

## Current state

### Export flow
- **Simple dispute PDF** (Dispute Builder): `PDFGenerator.generateDisputeSummary` → `ExportRepository.uploadExport(data, path)` (bucket `exports`, path e.g. `userId/propertyId/dispute_packet/uuid.pdf`) → `exportRepo.insertExport(ExportRow(..., filePath: storedPath))` → share sheet with PDF data. **file_path** = storage path.
- **Formal dispute packet** (Dispute Builder): Requires saved draft; `DisputeRepository.callGenerateDisputePacket` (Supabase function) returns a **signed URL**. We store **url.absoluteString** in `ExportRow.filePath` and share that URL. **file_path** = full URL (signed; will expire).
- **Move-in report** (Walkthrough): `PDFGenerator.generateMoveInReport` → `ExportRepository.uploadExport` → `insertExport(..., exportType: "move_in_report")` → share. Triggered from **RoomListView** “Export move-in report” card. **file_path** = storage path. Parity with move-out report flow.
- **Move-out report** (Move-out screen): `PDFGenerator.generateMoveOutReport` → upload to `exports` → `exportRepo.insertExport` → share. **file_path** = storage path.

### Export History
- **ExportHistoryView**: `ExportRepository.fetchExports(propertyId)` loads all exports for the property (RLS: user_id = auth.uid()). Sections: Move-in reports, Move-out reports, Dispute packets. Each row: label, date, short path, **Share**.
- **Share(row)**:
  - If **file_path** is missing → error.
  - If **file_path** starts with `http://` or `https://` → treat as absolute URL (formal packet case), share that URL directly.
  - Else → treat as **storage path**, call **ExportRepository.signedURL(filePath)** to get a fresh signed URL, then share. So upload-backed exports get a new 1h signed URL on each Share.

### Repository
- **ExportRepository**: `fetchExports(propertyId)`, `uploadExport(data, path)` (returns path), `insertExport(row)`, **signedURL(filePath)** — expects a **storage path**, not a full URL. Used by ExportHistoryView and DisputeBuilderView / MoveOutFoundationView.
- **ExportRow** (in DisputeRepository): id, disputeId?, propertyId, userId, exportType, filePath?, createdAt?. Used by both DisputeRepository.insertExportRecord and ExportRepository.insertExport.

### Formal packet edge function (field parity)
- **Location**: `supabase/functions/generate-dispute-packet/index.ts`.
- **Invoked by**: `DisputeRepository.callGenerateDisputePacket(disputeId, propertyId, jwt)`; client sends `dispute_id`, `property_id` in body; auth via `Authorization` header.
- **Behavior**: Loads dispute row with **move_out_date**, **received_itemized**, **charge_date** (same as simple PDF). Loads property; builds HTML packet that includes Title, Type, Amount, **Move-out date**, **Itemized charges received**, **Charge date**, Summary. Uploads HTML to `exports` bucket at `{user_id}/{property_id}/dispute_packet/{id}_{ts}.html`; returns `{ signed_url }`. Output aligns with simple PDF so both export paths show the same dispute metadata.
- **Deploy**: `supabase functions deploy generate-dispute-packet`. Ensure `exports` bucket exists and RLS allows authenticated upload to own path.

### Reliability notes
- **Storage-backed exports** (simple PDF, move-out report): file_path is a bucket path; Share in history uses signedURL() so the link is valid for 1h. Re-share gets a new signed URL.
- **Formal packet**: file_path is the signed URL from the edge function. It expires; re-share from history just re-sends the same URL (may be expired). **Improvement later**: edge function could return a storage path and write the PDF to the exports bucket; then we store that path and use signedURL() in history for a fresh link.
- **Draft-before-formal**: Dispute Builder “Generate formal packet” requires `disputeId` (save draft first). Error: “Save the draft first.” if not.

### Export / storage verification (Sprint 3 Item 14)
- **ExportVerificationStatus** (`Models/ExportVerificationStatus.swift`): `unknown`, `verifying`, `ready`, `missingPath`, `invalidURL`, `verificationFailed(String)`. Used to show per-row status in Export History.
- **ExportRepository.verify(filePath:)**:
  - Empty path → `.missingPath`.
  - Path starts with `http://` or `https://` → `URL(string:)` valid ? `.ready` : `.invalidURL`.
  - Otherwise storage path → try `signedURL(filePath:)` → success `.ready`, failure `.verificationFailed(message)`.
- **ExportHistoryView**: Per-row verification state (`verificationStatus: [UUID: ExportVerificationStatus]`). Each row shows status (Ready / Missing file path / Invalid link / Unavailable + message). **Verify** button for unknown or problem rows runs verification and updates status. **Share** sets per-row status on success (`.ready`) or failure (missing/invalid/verificationFailed) and shows `MMErrorBanner` on failure. Status cleared on load so pull-to-refresh starts fresh.

### Later
- Formal packet: persist storage path and generate signed URL on share.
- Export history: open in external app (e.g. Files) in addition to share.
