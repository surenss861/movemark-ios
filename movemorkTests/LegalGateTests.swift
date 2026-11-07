//
//  LegalGateTests.swift
//  movemorkTests
//
//  @file The status contract from `get_legal_status`, and what the app does with it.
//  @domain onboarding-auth
//  @status wip
//

import Foundation
import Testing
@testable import MoveMark

struct LegalGateTests {
    private func status(_ json: String) throws -> LegalStatus {
        try JSONDecoder().decode(LegalStatus.self, from: Data(json.utf8))
    }

    private let docs = #""documents":{"terms":{"version":"t1","url":"https://movemark.ca/terms"},"privacy_notice":{"version":"p1","url":null}}"#

    @Test func outstandingAcceptanceShowsTheGate() throws {
        let s = try status(#"{"enforced":false,"acceptance_required":true,"blocked":false,\#(docs)}"#)
        #expect(s.needsAcceptance)
        #expect(s.documents?.privacyNotice.version == "p1")
    }

    @Test func acceptedUsersSkipIt() throws {
        #expect(try !status(#"{"enforced":true,"acceptance_required":false,"blocked":false,\#(docs)}"#).needsAcceptance)
    }

    @Test func nothingPublishedMeansNoGate() throws {
        #expect(try !status(#"{"enforced":false,"acceptance_required":true,"blocked":false,"documents":null}"#).needsAcceptance)
    }

    @Test func methodFallsBackToEmail() {
        UserDefaults.standard.removeObject(forKey: "MoveMarkLastAuthMethod")
        #expect(LegalAcceptanceMethod.last == .email)
        LegalAcceptanceMethod.google.remember()
        #expect(LegalAcceptanceMethod.last == .google)
        UserDefaults.standard.removeObject(forKey: "MoveMarkLastAuthMethod")
    }
}
