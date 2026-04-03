//
//  DocumentRepository.swift
//  movemork
//
//  MoveMark — Property document data access.
//  Storage paths must stay under `{userId}/{propertyId}/...` so `storage.objects` RLS (auth.uid() prefix) matches uploads.
//

import Foundation
import Supabase

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
        case .lease: return "Lease"
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
    var fileName: String
    var uploadedAt: String?
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case userId = "user_id"
        case documentType = "document_type"
        case filePath = "file_path"
        case fileName = "file_name"
        case uploadedAt = "uploaded_at"
        case metadata
    }
}

struct DocumentRepository {

    // MARK: - Pipeline notes
    //
    // Supporting docs are three steps: (1) storage upload, (2) `property_documents` insert, (3) property snapshot / row refresh.
    // Callers should map failures per step (upload vs record vs refresh). Preview uses signed URLs only — not an upload failure.
    // Replace: delete existing rows + storage for that slot, then upload + insert again.

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

    /// Support older/newer storage layouts by falling back to `documents` when type-specific bucket is absent.
    private static func bucketCandidates(for documentType: String) -> [String] {
        let primary = bucket(for: documentType)
        if primary == "documents" { return ["documents"] }
        return [primary, "documents"]
    }

    private static func storageContentType(forPath path: String) -> String {
        let lower = path.lowercased()
        if lower.hasSuffix(".pdf") { return "application/pdf" }
        if lower.hasSuffix(".png") { return "image/png" }
        if lower.hasSuffix(".heic") { return "image/heic" }
        if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") { return "image/jpeg" }
        return "application/octet-stream"
    }

    /// Removes a file from storage. No-op if path is empty. Call before deleting DB row.
    private func removeFromStorage(bucket: String, path: String) async throws {
        guard !path.isEmpty else { return }
        try await supabase.storage
            .from(bucket)
            .remove(paths: [path])
    }

    func fetchDocuments(propertyId: UUID) async throws -> [PropertyDocumentRow] {
        try await supabase
            .from("property_documents")
            .select()
            .eq("property_id", value: propertyId)
            .order("uploaded_at", ascending: false)
            .execute()
            .value
    }

    /// Fetch documents for a property and optional document type filter (includes legacy type spellings).
    func fetchDocuments(propertyId: UUID, documentType: String) async throws -> [PropertyDocumentRow] {
        var query = supabase
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
            .execute()
            .value
    }

    func uploadDocument(data: Data, bucket: String, path: String) async throws -> String {
        let contentType = Self.storageContentType(forPath: path)
        let candidates = bucket == "documents" ? [bucket] : [bucket, "documents"]
        var lastError: Error?
        for candidate in candidates {
            do {
                try await supabase.storage
                    .from(candidate)
                    .upload(path, data: data, options: FileOptions(contentType: contentType))
                let segments = path.split(separator: "/")
                if segments.count >= 2 {
                    await MoveMarkSignedURLCache.shared.invalidateKeys(containing: String(segments[1]))
                }
                return path
            } catch {
                lastError = error
            }
        }
        throw lastError ?? NSError(domain: "MoveMark.DocumentRepository", code: 1)
    }

    func insertDocumentRecord(_ row: PropertyDocumentRow) async throws {
        try await supabase
            .from("property_documents")
            .insert(row)
            .execute()
    }

    /// After a successful storage upload, if the DB insert fails, remove the bytes from every bucket that might hold them (upload may have landed in a fallback bucket).
    func removeStaleUpload(documentType: String, path: String) async {
        guard !path.isEmpty else { return }
        for bucketName in Self.bucketCandidates(for: documentType) {
            try? await removeFromStorage(bucket: bucketName, path: path)
        }
    }

    /// Deletes one document: removes file from storage then DB row.
    func deleteDocument(id: UUID) async throws {
        let rows: [PropertyDocumentRow] = try await supabase
            .from("property_documents")
            .select()
            .eq("id", value: id)
            .execute()
            .value
        for row in rows {
            for bucketName in Self.bucketCandidates(for: row.documentType) {
                try? await removeFromStorage(bucket: bucketName, path: row.filePath)
            }
        }
        try await supabase
            .from("property_documents")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Deletes all document rows for the given property and type (canonical or legacy spelling).
    func deleteDocuments(propertyId: UUID, documentType: String) async throws {
        let keys = Self.documentTypeQueryKeys(documentType)
        let rows = try await fetchDocuments(propertyId: propertyId, documentType: documentType)
        var seen = Set<UUID>()
        for row in rows where seen.insert(row.id).inserted {
            for bucketName in Self.bucketCandidates(for: row.documentType) {
                try? await removeFromStorage(bucket: bucketName, path: row.filePath)
            }
        }
        var del = supabase
            .from("property_documents")
            .delete()
            .eq("property_id", value: propertyId)
        if keys.count == 1 {
            del = del.eq("document_type", value: keys[0])
        } else {
            del = del.in("document_type", values: keys)
        }
        try await del.execute()
    }

    func signedURL(bucket: String, path: String) async throws -> URL {
        let candidates = bucket == "documents" ? [bucket] : [bucket, "documents"]
        var lastError: Error?
        for candidate in candidates {
            do {
                return try await MoveMarkSignedURLCache.shared.url(bucket: candidate, path: path) {
                    try await supabase.storage
                        .from(candidate)
                        .createSignedURL(path: path, expiresIn: 3600)
                }
            } catch {
                lastError = error
                await MoveMarkSignedURLCache.shared.invalidate(bucket: candidate, path: path)
            }
        }
        throw lastError ?? NSError(domain: "MoveMark.DocumentRepository", code: 2)
    }
}
