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
    /// The age statement the renter must confirm (migration 1055). `nil` from a server without 1055, which
    /// neither records nor requires the confirmation.
    var ageRequirement: String? = nil
    /// The account's declared age category ('teen' or 'adult'), once declared through the age-range question.
    var ageCategory: String? = nil

    private enum CodingKeys: String, CodingKey {
        case enforced
        case acceptanceRequired = "acceptance_required"
        case blocked
        case documents
        case ageRequirement = "age_requirement"
        case ageCategory = "age_category"
    }

    /// Show the gate only when there is something real to accept.
    var needsAcceptance: Bool { acceptanceRequired && documents != nil }

    /// What the screen asks the renter to confirm. A server without 1055 gets the launch rule's wording (and the
    /// three-argument call); a code this build doesn't know means an older app: it can't confirm, and says so.
    var age: LegalAgeRequirement? {
        guard let ageRequirement else { return .thirteenQuebecFourteen }
        return LegalAgeRequirement(rawValue: ageRequirement)
    }
}

/// The statements the server may require (`legal_gate_settings.age_requirement`). The renter confirms one; no date of
/// birth is asked or kept.
nonisolated enum LegalAgeRequirement: String, Sendable, CaseIterable {
    /// The age-range question (migration 1055's default): 13 to 17, or 18 or older; under 13, and 13 in Quebec, are
    /// "not available yet" (Phase 2 needs parental consent).
    case ageRange = "bands_v1"
    case thirteenQuebecFourteen = "age_13_qc_14"
    case eighteen = "age_18"

    var confirmation: String {
        switch self {
        case .ageRange: "How old are you?"
        case .thirteenQuebecFourteen: "I’m 13 or older (14 or older if I live in Quebec)."
        case .eighteen: "I’m 18 or older."
        }
    }

    var explanation: String {
        switch self {
        case .ageRange:
            "MoveMark asks for your age range only, never your date of birth."
        case .thirteenQuebecFourteen:
            "MoveMark isn’t for children under 13 (under 14 in Quebec). If you’re under 18: your photos, documents and rental details are stored in the United States, nobody else sees them unless you share a report, and you can delete everything from Account at any time."
        case .eighteen:
            "MoveMark is for adults. Your photos, documents and rental details are stored in the United States, nobody else sees them unless you share a report, and you can delete everything from Account at any time."
        }
    }
}

/// `rpc accept_legal_documents`: the renter's decision and the versions they were shown. The server rejects anything
/// that isn't active, and sets the time and hashes itself.
nonisolated struct LegalAcceptanceParams: Encodable, Equatable, Sendable {
    let p_method: String
    let p_terms_version: String
    let p_privacy_notice_version: String
}

/// The same, with the age statement the renter confirmed: the four-argument overload from migration 1055. The
/// server refuses it unless the code is the one it currently requires, and only this call counts once enforced.
nonisolated struct LegalAcceptanceWithAgeParams: Encodable, Equatable, Sendable {
    let p_method: String
    let p_terms_version: String
    let p_privacy_notice_version: String
    let p_age_attestation: String
}

/// Which `accept_legal_documents` overload this status calls for. The server, not the app, decides what counts:
/// once enforcement is on, only the four-argument call with the current code opens the gate.
nonisolated enum LegalAcceptanceCall: Equatable, Sendable {
    /// A server without migration 1055: it neither records nor requires the age confirmation.
    case withoutAge(LegalAcceptanceParams)
    case withAge(LegalAcceptanceWithAgeParams)
    case withAgeBand(LegalAcceptanceWithBandParams)
    /// The server requires an age statement this build doesn't know.
    case updateRequired

    static func make(for status: LegalStatus, method: LegalAcceptanceMethod, band: LegalAgeBand? = nil) -> LegalAcceptanceCall? {
        guard let documents = status.documents else { return nil }
        guard status.ageRequirement != nil else {
            return .withoutAge(LegalAcceptanceParams(p_method: method.rawValue, p_terms_version: documents.terms.version,
                                                     p_privacy_notice_version: documents.privacyNotice.version))
        }
        guard let age = status.age else { return .updateRequired }
        if age == .ageRange {
            guard let band else { return nil }  // no eligible range chosen: nothing to send
            return .withAgeBand(LegalAcceptanceWithBandParams(p_method: method.rawValue, p_terms_version: documents.terms.version,
                                                              p_privacy_notice_version: documents.privacyNotice.version,
                                                              p_age_attestation: age.rawValue, p_age_band: band.rawValue))
        }
        return .withAge(LegalAcceptanceWithAgeParams(p_method: method.rawValue, p_terms_version: documents.terms.version,
                                                     p_privacy_notice_version: documents.privacyNotice.version,
                                                     p_age_attestation: age.rawValue))
    }
}

/// The renter's answer to the age-range question. No date of birth.
nonisolated enum LegalAgeChoice: String, Sendable, CaseIterable {
    case under13, thirteen, fourteenToSeventeen, adult

    var label: String {
        switch self {
        case .under13: "Under 13"
        case .thirteen: "13"
        case .fourteenToSeventeen: "14 to 17"
        case .adult: "18 or older"
        }
    }

    /// The range the server records, or nil when MoveMark isn't available yet (under 13; 13 in Quebec). A 13-year-old
    /// must answer the Quebec question first (`livesInQuebec` nil means "not answered").
    func band(livesInQuebec: Bool?) -> LegalAgeBand? {
        switch self {
        case .under13: nil
        case .thirteen: livesInQuebec == false ? .teen : nil
        case .fourteenToSeventeen: .teen
        case .adult: .adult
        }
    }

    /// Phase 1 can't serve this answer (parental consent is Phase 2).
    func isUnavailable(livesInQuebec: Bool?) -> Bool {
        self == .under13 || (self == .thirteen && livesInQuebec == true)
    }
}

nonisolated enum LegalAgeBand: String, Sendable {
    case teen = "13_17"
    case adult = "18_plus"
}

/// The five-argument overload (migration 1055, 'bands_v1').
nonisolated struct LegalAcceptanceWithBandParams: Encodable, Equatable, Sendable {
    let p_method: String
    let p_terms_version: String
    let p_privacy_notice_version: String
    let p_age_attestation: String
    let p_age_band: String
}

/// Why `get_legal_status` gave no answer, which decides where the renter lands.
nonisolated enum LegalStatusFailure: Error, Equatable, Sendable {
    /// The server has no legal gate (PGRST202 before migration 1030): nothing to offer, nothing enforced.
    case serverWithoutGate
    /// The request never reached the server. The app opens on its cache; data reads fail the same way, so no
    /// empty answer can replace it.
    case offline
    /// The server answered, but not with a status. With enforcement possibly on, the data reads might answer
    /// with empty lists, so the app must not open the Vault on a guess (rollout plan, "what the apps must get right" 1).
    case unavailable

    static func classify(_ error: Error) -> LegalStatusFailure {
        if error is URLError { return .offline }
        if String(describing: error).contains("PGRST202") { return .serverWithoutGate }
        return .unavailable
    }
}

/// The MoveMark API's refusal for a renter who hasn't accepted (`require_legal_acceptance`): the app re-reads status.
nonisolated enum LegalAcceptanceRequiredSignal {
    static let code = "LEGAL_ACCEPTANCE_REQUIRED"

    static func matches(data: Data, response: URLResponse, apiHost: String?) -> Bool {
        guard let http = response as? HTTPURLResponse, http.statusCode == 403,
              let host = http.url?.host?.lowercased(), host == apiHost else { return false }
        struct Body: Decodable { let code: String? }
        return (try? JSONDecoder().decode(Body.self, from: data))?.code == code
    }
}

extension Notification.Name {
    static let moveMarkLegalAcceptanceRequired = Notification.Name("MoveMark.legalAcceptanceRequired")
}

/// How the renter signed in, for the acceptance record. Not an authority on anything.
nonisolated enum LegalAcceptanceMethod: String, Sendable {
    case email
    case apple
    case google

    private static let key = "MoveMarkLastAuthMethod"

    static var last: LegalAcceptanceMethod {
        LegalAcceptanceMethod(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .email
    }

    func remember() { UserDefaults.standard.set(rawValue, forKey: Self.key) }
}
