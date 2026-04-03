//
//  ExportVerificationStatus.swift
//  movemork
//
//  MoveMark — Per-export verification state for Export History.
//

import Foundation

enum ExportVerificationStatus: Equatable {
    /// List row reflects API `queued` — not failed, not necessarily ready for download yet.
    case queued
    case unknown
    case verifying
    case ready
    case processing
    case missingPath
    case invalidURL
    /// API `failed` — terminal; user should generate a new export.
    case serverFailed
    case verificationFailed(String)

    var displayLabel: String {
        switch self {
        case .queued: return "Queued"
        case .unknown: return "Not checked"
        case .verifying: return "Checking file"
        case .ready: return "Ready to share"
        case .processing: return "Still processing"
        case .missingPath: return "Missing file path"
        case .invalidURL: return "Link unavailable"
        case .serverFailed: return "Export failed"
        case .verificationFailed: return "Couldn’t verify"
        }
    }

    var isProblem: Bool {
        switch self {
        case .unknown, .verifying, .processing, .queued: return false
        case .ready: return false
        case .missingPath, .invalidURL, .serverFailed, .verificationFailed: return true
        }
    }
}
