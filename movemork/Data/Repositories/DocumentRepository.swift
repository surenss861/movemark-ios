//
//  DocumentRepository.swift
//  movemork
//
//  MoveMark — Property document data access.
//  Files go through the MoveMark API, which picks the bucket from the document type and builds the key
//  (`{userId}/{propertyId}/{documentType}/{uuid}.{pdf|jpg|png}`); the app records the returned path.
//

import Foundation
import PostgREST

/// Supporting document types; raw values match `property_documents.document_type` CHECK / DB enums (snake_case).
enum VaultDocumentType: String, CaseIterable {
    case lease = "lease"
    case depositReceipt = "deposit_receipt"
    case listingScreenshot = "listing_screenshot"
    case cleaningReceipt = "cleaning_receipt"
    case utilityProof = "utility_record"
    case moveOutInvoice = "move_out_invoice"
    case other = "other"

    var displayTitle: String {
        switch self {
        case .lease: return "lease"
        case .depositReceipt: return "Deposit receipt"
        case .listingScreenshot: return "Listing proof"
        case .cleaningReceipt: return "Cleaning receipt"
        case .utilityProof: return "Utility proof"
        case .moveOutInvoice: return "Move-out invoice"
        case .other: return "Other"
        }
    }

    var acceptsImage: Bool {
        self == .listingScreenshot
    }
}

struct PropertyDocumentRow: Codable, Identifiable {
    let id: UUID
    let propertyId: UUID
    let userId: UUID
    var documentType: String
    var filePath: String
    /// Small (~320px) JPEG uploaded alongside `filePath` for image document types (e.g. listing screenshot); `nil` otherwise or for rows captured before this existed.
    var thumbnailPath: String? = nil
    var fileName: String
    var uploadedAt: String?
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case userId = "user_id"
        case documentType = "document_type"
        case filePath = "file_path"
        case thumbnailPath = "thumbnail_path"
        case fileName = "file_name"
        case uploadedAt = "uploaded_at"
        case metadata
    }
}

struct DocumentRepository {

    // MARK: - Pipeline notes
    //
    // Supporting docs are three steps: (1) storage upload, (2) `property_documents` insert, (3) property snapshot / row refresh.
    // Callers should map failures per step (upload vs record vs refresh); a failed insert abandons the upload.
    // Preview uses temporary download URLs only — not an upload failure.
    // Replace: upload + insert the new copy, then retire the old rows (and their files) server-side.

    /// Canonical `document_type` for DB + storage path segments (legacy app builds used kebab-case for two types).
    static func normalizedDocumentType(_ raw: String) -> String {
        switch raw {
        case "deposit-receipt": return "deposit_receipt"
        case "listing-screenshot": return "listing_screenshot"
        default: return raw
        }
    }

    /// All `document_type` values to match when querying or deleting (current + legacy).
    static func documentTypeQueryKeys(_ raw: String) -> [String] {
        let n = normalizedDocumentType(raw)
        var keys: Set<String> = [n, raw]
        if n == "deposit_receipt" { keys.insert("deposit-receipt") }
        if n == "listing_screenshot" { keys.insert("listing-screenshot") }
        return Array(keys)
    }

    /// Storage bucket for a document type string (may be legacy hyphenated).
    static func storageBucket(forDocumentType raw: String) -> String {
        bucket(for: normalizedDocumentType(raw))
    }

    /// Bucket name for a normalized document type.
    private static func bucket(for documentType: String) -> String {
        let t = normalizedDocumentType(documentType)
        switch t {
        case "lease": return "leases"
        case "deposit_receipt": return "deposit-receipts"
        case "listing_screenshot": return "listing-screenshots"
        case "cleaning_receipt", "utility_record", "move_out_invoice", "other": return "documents"
        default: return "documents"
        }
    }

    private static func storageContentType(forPath path: String) -> String {
        let lower = path.lowercased()
        if lower.hasSuffix(".pdf") { return "application/pdf" }
        if lower.hasSuffix(".png") { return "image/png" }
        if lower.hasSuffix(".heic") { return "image/heic" }
        if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") { return "image/jpeg" }
        return "application/octet-stream"
    }

    /// Capped so a long-tenured account can't grow this into an unbounded fetch; ordered so the cap keeps the most recent documents.
    func fetchDocuments(propertyId: UUID) async throws -> [PropertyDocumentRow] {
        try await dataAPI
            .from("property_documents")
            .select()
            .eq("property_id", value: propertyId)
            .order("uploaded_at", ascending: false)
            .limit(300)
            .execute()
            .value
    }

    /// Fetch documents for a property and optional document type filter (includes legacy type spellings).
    func fetchDocuments(propertyId: UUID, documentType: String) async throws -> [PropertyDocumentRow] {
        var query = dataAPI
            .from("property_documents")
            .select()
            .eq("property_id", value: propertyId)
        if !documentType.isEmpty {
            let keys = Self.documentTypeQueryKeys(documentType)
            if keys.count == 1 {
                query = query.eq("document_type", value: keys[0])
            } else {
                query = query.in("document_type", values: keys)
            }
        }
        return try await query
            .order("uploaded_at", ascending: false)
            .limit(300)
            .execute()
            .value
    }

    /// Uploads a document (type from `fileName`'s extension; the API accepts PDF, JPEG and PNG) and an
    /// optional thumbnail under a key the API builds for this property and document type.
    func uploadDocument(_ data: Data, fileName: String, thumbnail: Data?, propertyId: UUID, documentType: String) async throws -> MoveMarkUpload {
        let upload = try await MoveMarkStorageService.shared.uploadDocument(
            data,
            contentType: Self.storageContentType(forPath: fileName),
            thumbnail: thumbnail,
            propertyId: propertyId,
            documentType: Self.normalizedDocumentType(documentType)
        )
        await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)
        return upload
    }

    func insertDocumentRecord(_ row: PropertyDocumentRow) async throws {
        try await dataAPI
            .from("property_documents")
            .insert(row)
            .execute()
    }

    /// Releases an upload whose `property_documents` insert failed. Safe even if the insert actually
    /// committed: the API keeps any object a row references.
    func abandonUpload(_ upload: MoveMarkUpload) async {
        await MoveMarkStorageService.shared.abandon(upload)
    }

    /// Deletes one document: the API removes its file(s) and its row together.
    func deleteDocument(id: UUID) async throws {
        let rows: [PropertyDocumentRow] = try await dataAPI
            .from("property_documents")
            .select()
            .eq("id", value: id)
            .execute()
            .value
        try await MoveMarkStorageService.shared.deleteDocuments(ids: [id])
        if let pid = rows.first?.propertyId {
            await MoveMarkSignedURLCache.shared.invalidateKeys(containing: pid.uuidString)
        }
    }

    /// Retires a replaced document after its successor is saved. Best-effort: a failure leaves the old
    /// copy in place (and visible), never a row pointing at a missing file.
    func retireDocument(_ row: PropertyDocumentRow) async {
        do {
            try await MoveMarkStorageService.shared.deleteDocuments(ids: [row.id])
        } catch {
            return
        }
        await MoveMarkSignedURLCache.shared.invalidateKeys(containing: row.propertyId.uuidString)
    }

    /// Deletes all document rows for the given property and type (canonical or legacy spelling), with their files.
    func deleteDocuments(propertyId: UUID, documentType: String) async throws {
        let rows = try await fetchDocuments(propertyId: propertyId, documentType: documentType)
        try await MoveMarkStorageService.shared.deleteDocuments(ids: rows.map(\.id))
        await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)
    }

    /// Temporary download URL for a stored document path (original or thumbnail).
    func signedURL(bucket: String, path: String) async throws -> URL {
        try await MoveMarkStoredFileURLs.documentURL(bucket: bucket, path: path)
    }
}
