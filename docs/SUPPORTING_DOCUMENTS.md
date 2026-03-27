# Supporting Documents — Build summary

## Current state (v1)

### Done
- **PropertyStore.fetchAll** — Fetches `property_documents` and sets `currentProperty.vaultDocuments` to the list of document types present. Single source of truth for “uploaded vs missing” in Vault.
- **PropertyStore.refreshDocuments(propertyId:)** — After upload/delete, refreshes `currentProperty.vaultDocuments` so the Vault section updates.
- **PropertyVaultView** — Supporting records section is data-driven from `VaultDocumentType`. Loads `documentRows` via `fetchDocuments(propertyId:)` in `.task(id: property.id)` for preview/delete. Upload flow calls `propertyStore.refreshDocuments(propertyId:)` and `loadDocumentRows()` after success.
- **Document types** — `VaultDocumentType`: `lease`, `depositReceipt`, `listingScreenshot`, `cleaningReceipt`, `utilityProof`, `moveOutInvoice`, `other`. Each has `displayTitle` and `acceptsImage` (only listing uses PhotosPicker; rest use file picker PDF).
- **Upload flow** — PDF via `.fileImporter`; listing screenshots via `PhotosPicker`. Replace: deletes existing rows for that type before insert. Upload → storage → `property_documents` row → refresh + reload document rows.
- **Preview** — “Preview” opens signed URL in Safari. Uses first document row for that type; `previewErrorMessage` on failure.
- **Delete** — “Delete” shows confirmation dialog; on confirm calls `DocumentRepository.deleteDocuments(propertyId:documentType:)`, then `refreshDocuments` and `loadDocumentRows()`.
- **DocumentRepository** — `fetchDocuments(propertyId:)`, `uploadDocument`, `insertDocumentRecord`, `deleteDocument(id:)`, `deleteDocuments(propertyId:documentType:)`, `signedURL(bucket:path:)`.

### Flow
1. User opens Vault → `property.vaultDocuments` from store; `documentRows` loaded in `.task` for current property.
2. Supporting records card lists all types (Lease, Deposit receipt, Listing screenshots, Cleaning receipt, Utility proof, Move-out invoice, Other) with Uploaded/Missing.
3. When present: Preview (open in Safari), Replace (file or photo), Delete (with confirmation).
4. When absent: “Upload PDF” or “Upload screenshot” for listing.
5. Replace deletes existing rows for that type then uploads; counts stay in sync.

### Storage buckets
- `leases`, `deposit-receipts`, `listing-screenshots` for the original three types.
- `documents` for `cleaning_receipt`, `utility_record`, `move_out_invoice`, `other`. Ensure a `documents` bucket exists in Supabase Storage.

### Later
- In-app document viewer (e.g. WebView) instead of opening Safari.
- Optional storage object deletion when deleting a document row (currently only row is removed).
