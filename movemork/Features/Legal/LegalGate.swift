//
//  LegalGate.swift
//  movemork
//
//  @file The app's side of the legal gate. The server owns it: the active documents, the versions, the time of
//        acceptance and enforcement. This file only reads the status and reports the renter's decision. Nothing here
//        is ever remembered as "accepted" on the device.
//  @domain onboarding-auth
//  @status wip
//  @see [[LegalAcceptanceScreen.swift]]
//

import Foundation

nonisolated struct LegalDocument: Decodable, Equatable, Sendable {
    let version: String
    let url: String?
}

nonisolated struct LegalDocuments: Decodable, Equatable, Sendable {
    let terms: LegalDocument
    let privacyNotice: LegalDocument

    private enum CodingKeys: String, CodingKey {
        case terms
        case privacyNotice = "privacy_notice"
    }
}

/// `rpc get_legal_status()`.
nonisolated struct LegalStatus: Decodable, Equatable, Sendable {
    let enforced: Bool
    let acceptanceRequired: Bool
    let blocked: Bool
    let documents: LegalDocuments?

    private enum CodingKeys: String, CodingKey {
        case enforced
        case acceptanceRequired = "acceptance_required"
        case blocked
        case documents
    }

    /// Show the gate only when there is something real to accept.
    var needsAcceptance: Bool { acceptanceRequired && documents != nil }
}

/// `rpc accept_legal_documents`: the renter's decision and the versions they were shown. The server rejects anything
/// that isn't active, and sets the time and hashes itself.
nonisolated struct LegalAcceptanceParams: Encodable, Sendable {
    let p_method: String
    let p_terms_version: String
    let p_privacy_notice_version: String
}

/// How the renter signed in, for the acceptance record. Not an authority on anything.
enum LegalAcceptanceMethod: String, Sendable {
    case email
    case apple
    case google

    private static let key = "MoveMarkLastAuthMethod"

    static var last: LegalAcceptanceMethod {
        LegalAcceptanceMethod(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .email
    }

    func remember() { UserDefaults.standard.set(rawValue, forKey: Self.key) }
}
