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

extension LegalGateTests {
    /// Production has no gate yet: the status call fails, and `enter` must carry on as if there were nothing to accept.
    @Test func aServerWithoutTheGateDecodesToNoGate() {
        let missing = try? JSONDecoder().decode(LegalStatus.self, from: Data(#"{"code":"PGRST202","message":"Could not find the function"}"#.utf8))
        #expect(missing == nil || missing?.needsAcceptance == false)
    }
}

// MARK: - Age confirmation (migration 1055) and enforcement readiness

extension LegalGateTests {
    @Test func aServerWithTheAgeStepGetsTheFourArgumentCall() throws {
        let s = try status(#"{"enforced":false,"acceptance_required":true,"blocked":false,"age_requirement":"age_13_qc_14",\#(docs)}"#)
        #expect(s.age == .thirteenQuebecFourteen)
        #expect(LegalAcceptanceCall.make(for: s, method: .apple) == .withAge(
            LegalAcceptanceWithAgeParams(p_method: "apple", p_terms_version: "t1", p_privacy_notice_version: "p1", p_age_attestation: "age_13_qc_14")))
    }

    @Test func theEighteenPlusFallbackIsConfirmedAsSuch() throws {
        let s = try status(#"{"enforced":true,"acceptance_required":true,"blocked":true,"age_requirement":"age_18",\#(docs)}"#)
        #expect(s.age == .eighteen)
        guard case .withAge(let params) = LegalAcceptanceCall.make(for: s, method: .email) else { Issue.record("expected withAge"); return }
        #expect(params.p_age_attestation == "age_18")
    }

    @Test func aServerWithoutTheAgeStepGetsTheThreeArgumentCallButTheScreenStillAsks() throws {
        let s = try status(#"{"enforced":false,"acceptance_required":true,"blocked":false,\#(docs)}"#)
        #expect(s.ageRequirement == nil)
        #expect(s.age == .thirteenQuebecFourteen)  // the box is shown either way
        #expect(LegalAcceptanceCall.make(for: s, method: .email) == .withoutAge(
            LegalAcceptanceParams(p_method: "email", p_terms_version: "t1", p_privacy_notice_version: "p1")))
    }

    @Test func anUnknownAgeStatementMeansUpdateTheApp() throws {
        let s = try status(#"{"enforced":true,"acceptance_required":true,"blocked":true,"age_requirement":"age_21",\#(docs)}"#)
        #expect(s.age == nil)
        #expect(LegalAcceptanceCall.make(for: s, method: .email) == .updateRequired)
    }

    @Test func theFourArgumentBodyNamesExactlyTheServerParameters() throws {
        let body = try JSONEncoder().encode(LegalAcceptanceWithAgeParams(p_method: "email", p_terms_version: "t", p_privacy_notice_version: "p", p_age_attestation: "age_13_qc_14"))
        let keys = try #require(JSONSerialization.jsonObject(with: body) as? [String: String]).keys.sorted()
        #expect(keys == ["p_age_attestation", "p_method", "p_privacy_notice_version", "p_terms_version"])
    }

    @MainActor
    @Test func theScreenWontContinueWithoutBothBoxesOrAKnownStatement() {
        #expect(!LegalAcceptanceScreen(termsURL: nil, privacyURL: nil).canContinue)  // both start unticked
        #expect(!LegalAcceptanceScreen(termsURL: nil, privacyURL: nil, age: nil).canContinue)
    }

    @Test func statusFailuresAreClassified() {
        #expect(LegalStatusFailure.classify(URLError(.notConnectedToInternet)) == .offline)
        struct FakePostgrest: Error { let code = "PGRST202"; let message = "Could not find the function public.get_legal_status" }
        #expect(LegalStatusFailure.classify(FakePostgrest()) == .serverWithoutGate)
        struct FakeServerError: Error { let code = "XX000"; let message = "internal" }
        #expect(LegalStatusFailure.classify(FakeServerError()) == .unavailable)
        #expect(LegalStatusFailure.classify(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "x"))) == .unavailable)
    }

    @Test func onlyTheAPIs403WithTheLegalCodeSignalsTheGate() throws {
        func response(_ host: String, _ status: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: URL(string: "https://\(host)/api/storage/uploads")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
        let body = Data(#"{"error":"Accept the current Terms and Privacy Notice to continue.","code":"LEGAL_ACCEPTANCE_REQUIRED"}"#.utf8)
        #expect(LegalAcceptanceRequiredSignal.matches(data: body, response: response("api.test", 403), apiHost: "api.test"))
        #expect(!LegalAcceptanceRequiredSignal.matches(data: body, response: response("elsewhere.test", 403), apiHost: "api.test"))
        #expect(!LegalAcceptanceRequiredSignal.matches(data: body, response: response("api.test", 402), apiHost: "api.test"))
        #expect(!LegalAcceptanceRequiredSignal.matches(data: Data(#"{"code":"FORBIDDEN"}"#.utf8), response: response("api.test", 403), apiHost: "api.test"))
    }
}
