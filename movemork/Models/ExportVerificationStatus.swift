//
//  ExportVerificationStatus.swift
//  movemork
//
//  MoveMark — Per-export verification state for Export History.
//

import Foundation

enum ExportVerificationStatus: Equatable {
    case unknown
    case verifying
    case ready
    case missingPath
    case invalidURL
    case verificationFailed(String)

    var displayLabel: String {
        switch self {
        case .unknown: return "Not checked"
        case .verifying: return "Checking file"
        case .ready: return "Ready to share"
        case .missingPath: return "Missing file path"
        case .invalidURL: return "Link unavailable"
        case .verificationFailed: return "Verification failed"
        }
    }

    var isProblem: Bool {
        switch self {
        case .unknown, .verifying: return false
        case .ready: return false
        case .missingPath, .invalidURL, .verificationFailed: return true
        }
    }
}
