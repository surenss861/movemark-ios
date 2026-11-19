//
//  MMEvidenceRetryQAFixture.swift
//  movemork
//
//  DEBUG only: `-MMRichQA evidence-retry` pushes the production EvidenceCaptureView (123 Main St → Storage) in a
//  partial-save state: "2 of 8 photos saved. 6 photos need retry." with its Retry buttons, as after a save where
//  only some photos made it. The retry state arrives the way a restored one does (after the screen is on
//  screen), so the screen's own scroll-to-warning runs. Used by EvidenceRetryHittableUITests.
//
//  @file Debug-only fixture: the real room evidence screen with a pending upload retry
//  @domain evidence
//  @status stable
//  @see [[EvidenceCaptureView.swift]]
//

#if DEBUG
import SwiftUI
import UIKit

enum MMEvidenceRetryQAFixture {
    /// Set by the fixture before the screen appears; read once by `restorePendingCaptures`.
    @MainActor static var seed: EvidenceRetryState?

    @MainActor static func makeSeed() -> EvidenceRetryState {
        let pending = (0..<6).map { _ in
            MMPendingEvidence(source: MMEvidenceSource(
                data: Data(), mimeType: "image/jpeg", fileExtension: "jpg", pixelWidth: 1, pixelHeight: 1,
                sha256Hex: "", capturedAt: nil, captureSource: .library))
        }
        let previews = Dictionary(uniqueKeysWithValues: pending.enumerated().map { index, item in
            (item.id, tile(index))
        })
        return EvidenceRetryState(entryId: UUID(), pending: pending, previews: previews, savedCount: 2,
                                  requestedCount: 8, issueCount: 0,
                                  outcomeHints: PropertyMutationOutcome(hydrationRefreshFailed: false))
    }

    private static func tile(_ index: Int) -> UIImage {
        let hues: [CGFloat] = [0.08, 0.12, 0.55, 0.6, 0.3, 0.95]
        return UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300)).image { ctx in
            UIColor(hue: hues[index % hues.count], saturation: 0.25, brightness: 0.7, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
    }
}

struct MMEvidenceRetryQAScreen: View {
    @State private var propertyStore: PropertyStore
    @State private var sessionManager = SessionManager()
    @State private var path: [UUID]
    private let room: RoomRecord

    init() {
        let entry = EvidenceRecord(title: "Storage", notes: "", issueTags: [], condition: .good,
                                   createdAt: Date().addingTimeInterval(-120), photoCount: 2,
                                   photos: (0..<2).map { EvidencePhoto(id: UUID(), filePath: "qa-fixture/storage-\($0).jpg") },
                                   stage: .moveIn)
        let room = RoomRecord(name: "Storage", evidence: [entry])
        let store = PropertyStore()
        store.currentProperty = PropertyRecord(title: "123 Main St", addressLine1: "123 Main St",
                                               moveInDate: Date(), leaseEndDate: Date().addingTimeInterval(86_400 * 365),
                                               rooms: [room])
        self.room = room
        _propertyStore = State(initialValue: store)
        _path = State(initialValue: [room.id])
        MMEvidenceRetryQAFixture.seed = MMEvidenceRetryQAFixture.makeSeed()
    }

    var body: some View {
        NavigationStack(path: $path) {
            Text("123 Main St")
                .navigationDestination(for: UUID.self) { id in
                    EvidenceCaptureView(roomID: id, roomName: room.name)
                }
        }
        .environment(propertyStore)
        .environment(sessionManager)
        .preferredColorScheme(.dark)
    }
}
#endif
