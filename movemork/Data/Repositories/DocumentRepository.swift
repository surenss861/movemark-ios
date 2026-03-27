//
//  DocumentRepository.swift
//  movemork
//
//  MoveMark — Property document data access.
//

import Foundation
import Supabase

/// Supporting document types; raw values match DB document_type and storage.
enum VaultDocumentType: String, CaseIterable {
    case lease = "lease"
    case depositReceipt = "deposit-receipt"
    case listingScreenshot = "listing-screenshot"
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

    /// Bucket name for a given document type (matches storage layout).
    private static func bucket(for documentType: String) -> String {
        switch documentType {
        case "lease": return "leases"
        case "deposit-receipt": return "deposit-receipts"
        case "listing-screenshot": return "listing-screenshots"
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

    /// Fetch documents for a property and optional document type filter.
    func fetchDocuments(propertyId: UUID, documentType: String) async throws -> [PropertyDocumentRow] {
        var query = supabase
            .from("property_documents")
            .select()
            .eq("property_id", value: propertyId)
        if !documentType.isEmpty {
            query = query.eq("document_type", value: documentType)
        }
        return try await query
            .order("uploaded_at", ascending: false)
            .execute()
            .value
    }

    func uploadDocument(data: Data, bucket: String, path: String) async throws -> String {
        let contentType = path.hasSuffix(".pdf") ? "application/pdf" : "image/jpeg"
        let candidates = bucket == "documents" ? [bucket] : [bucket, "documents"]
        var lastError: Error?
        for candidate in candidates {
            do {
                try await supabase.storage
                    .from(candidate)
                    .upload(path, data: data, options: FileOptions(contentType: contentType))
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

    /// Deletes all document rows for the given property and type; removes each file from storage first (e.g. before replace).
    func deleteDocuments(propertyId: UUID, documentType: String) async throws {
        let rows: [PropertyDocumentRow] = try await fetchDocuments(propertyId: propertyId, documentType: documentType)
        for row in rows {
            for bucketName in Self.bucketCandidates(for: documentType) {
                try? await removeFromStorage(bucket: bucketName, path: row.filePath)
            }
        }
        try await supabase
            .from("property_documents")
            .delete()
            .eq("property_id", value: propertyId)
            .eq("document_type", value: documentType)
            .execute()
    }

    func signedURL(bucket: String, path: String) async throws -> URL {
        let candidates = bucket == "documents" ? [bucket] : [bucket, "documents"]
        var lastError: Error?
        for candidate in candidates {
            do {
                return try await supabase.storage
                    .from(candidate)
                    .createSignedURL(path: path, expiresIn: 3600)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? NSError(domain: "MoveMark.DocumentRepository", code: 2)
    }
}
