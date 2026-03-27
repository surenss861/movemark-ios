//
//  ExportRepository.swift
//  movemork
//
//  MoveMark — Export record and file storage access.
//

import Foundation
import Supabase

struct ExportRepository {

    func fetchExports(propertyId: UUID) async throws -> [ExportRow] {
        try await supabase
            .from("exports")
            .select()
            .eq("property_id", value: propertyId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func uploadExport(data: Data, path: String) async throws -> String {
        try await supabase.storage
            .from("exports")
            .upload(path, data: data, options: FileOptions(contentType: "application/pdf"))
        return path
    }

    func insertExport(_ row: ExportRow) async throws {
        try await supabase
            .from("exports")
            .insert(row)
            .execute()
    }

    func signedURL(filePath: String) async throws -> URL {
        try await supabase.storage
            .from("exports")
            .createSignedURL(path: filePath, expiresIn: 3600)
    }

    /// Verifies that an export row's file_path points to a usable file.
    /// - Returns: `.ready` if path is valid and (for storage paths) signed URL succeeds; otherwise a specific failure.
    func verify(filePath: String?) async -> ExportVerificationStatus {
        let path = filePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if path.isEmpty {
            return .missingPath
        }

        let lower = path.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: path) != nil ? .ready : .invalidURL
        }

        do {
            _ = try await signedURL(filePath: path)
            return .ready
        } catch {
            return .verificationFailed(error.localizedDescription)
        }
    }
}
