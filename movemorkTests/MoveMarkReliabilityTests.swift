//
//  MoveMarkReliabilityTests.swift
//  movemorkTests
//
//  Lightweight logic tests for vibe-cleanup invariants.
//

import Foundation
import Testing
@testable import MoveMark

struct MoveMarkReliabilityTests {

    @Test func roomDocumentedRequiresPhotosNotEmptyEvidenceRows() {
        let roomWithEmptyEntry = RoomRecord(
            id: UUID(),
            name: "Kitchen",
            evidence: [
                EvidenceRecord(
                    title: "Kitchen",
                    notes: "",
                    issueTags: [],
                    condition: .good,
                    photoCount: 0,
                    photos: [],
                    stage: .moveIn
                ),
            ],
            moveOutEvidence: []
        )
        #expect(MMRoomProofMetrics.isDocumented(roomWithEmptyEntry) == false)
        #expect(!roomWithEmptyEntry.evidence.isEmpty)

        let roomWithPhotos = RoomRecord(
            id: UUID(),
            name: "Bedroom",
            evidence: [
                EvidenceRecord(
                    title: "Bedroom",
                    notes: "",
                    issueTags: [],
                    condition: .good,
                    photoCount: 2,
                    photos: [],
                    stage: .moveIn
                ),
            ],
            moveOutEvidence: []
        )
        #expect(MMRoomProofMetrics.isDocumented(roomWithPhotos) == true)
    }

    @Test func sessionExpiryDetection() {
        struct FakeAuthError: LocalizedError {
            var errorDescription: String? { "JWT expired" }
        }
        #expect(MoveMarkSessionExpiry.requiresReauthentication(FakeAuthError()) == true)
        #expect(MoveMarkSessionExpiry.requiresReauthentication(NSError(domain: "Test", code: 0)) == false)
    }

    @Test func subscriptionPlansErrorSanitization() {
        let raw = "RevenueCat offerings metadata test_ key appl_ invalid"
        let sanitized = SubscriptionManager.sanitizedPlansErrorMessage(raw)
        #expect(sanitized == "Plans didn't load. Try again.")
    }

    @Test func exportVerificationStatusLabels() {
        #expect(ExportVerificationStatus.queued.displayLabel == "Queued")
        #expect(ExportVerificationStatus.processing.displayLabel == "Still processing")
        #expect(ExportVerificationStatus.serverFailed.isProblem == true)
        #expect(ExportVerificationStatus.ready.isProblem == false)
    }
}
