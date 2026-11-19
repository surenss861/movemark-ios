//
//  LargeRentalPerformanceTests.swift
//  movemorkTests
//
//  @file Model work a large rental costs per screen render: 30 rooms, 300 photo rows (10 per room across
//        three entries with 1,500-character notes) and 100 maintenance cases. Each measure block runs the
//        computations one body evaluation of a screen does, 100 times, so regressions to per-render O(n²)
//        work show up as a step change. Also pins that the totals stay right.
//  @domain performance
//  @see [[PropertyStore+Workflow.swift]] [[RoomRecord.swift]]
//

import XCTest
@testable import MoveMark

@MainActor
final class LargeRentalPerformanceTests: XCTestCase {
    private static let day = Date(timeIntervalSince1970: 1_760_900_000)
    private static let notes: String = String(repeating: "Paint bubbling along the baseboard beside the window. ", count: 30).prefix(1500).description

    private static func uuid(_ group: Int, _ n: Int) -> UUID {
        UUID(uuidString: String(format: "0BAD0000-0000-4000-%04d-%012d", group, n))!
    }

    /// 30 rooms × 3 entries; 300 move-in photo rows in all (4 + 3 + 3 per room), move-out in half the rooms.
    static let rooms: [RoomRecord] = (0..<30).map { r in
        let entries = [4, 3, 3].enumerated().map { e, count in
            EvidenceRecord(id: uuid(1, r * 10 + e), title: "Wall \(e)", notes: notes, issueTags: e == 0 ? ["Scratch", "Stain"] : [],
                           condition: .fair, createdAt: day.addingTimeInterval(Double(r * 100 + e)), photoCount: count,
                           photos: (0..<count).map { EvidencePhoto(id: uuid(2, r * 100 + e * 10 + $0), filePath: "u/p/move-in/\(r)/\(e)-\($0).jpg",
                                                                   thumbnailPath: "u/p/move-in/\(r)/\(e)-\($0)-thumb.jpg") },
                           stage: .moveIn)
        }
        let moveOut = r % 2 == 0 ? [EvidenceRecord(id: uuid(3, r), title: "Wall", notes: notes, issueTags: ["Stain", "Dent"],
                                                   condition: .poor, createdAt: day.addingTimeInterval(9_000_000), photoCount: 2,
                                                   photos: (0..<2).map { EvidencePhoto(id: uuid(4, r * 10 + $0), filePath: "u/p/move-out/\(r)/\($0).jpg") },
                                                   stage: .moveOut)] : []
        return RoomRecord(id: uuid(5, r), name: "Room \(r)", evidence: entries, moveOutEvidence: moveOut)
    }

    static let property = PropertyRecord(id: uuid(6, 1), title: "Harbourfront Lofts Residence at Queens Quay W",
                                         addressLine1: "88 Harbour St", moveInDate: day, leaseEndDate: day.addingTimeInterval(31_536_000),
                                         rooms: rooms, vaultDocuments: ["lease"])

    static let cases: [MaintenanceRecord] = (0..<100).map { i in
        MaintenanceRecord(id: uuid(7, i), title: "Case \(i)", category: "Plumbing", details: notes,
                          status: [.open, .followUp, .resolved][i % 3], createdAt: day, photoCount: i % 4)
    }

    private static let iterations = 100

    private func store() -> PropertyStore {
        let store = PropertyStore()
        store.currentProperty = Self.property
        store.maintenanceLog = Self.cases
        return store
    }

    func testFixtureTotals() {
        let store = store()
        XCTAssertEqual(store.totalPhotoCount(for: Self.property), 300)
        XCTAssertEqual(store.documentedRoomCount(for: Self.property), 30)
        XCTAssertEqual(store.openIssueCount(for: Self.property), 67)
        XCTAssertEqual(store.totalNoteCount(for: Self.property), 90)
        XCTAssertEqual(Self.rooms[0].moveInPhotoTotal, 10)
        XCTAssertEqual(Self.rooms[0].moveInIssueTagTotal, 2)
        XCTAssertEqual(Self.rooms[0].moveOutPhotoTotal, 2)
    }

    /// What Proof (VaultRootView.proofHomeModel) asks the store for on every body evaluation.
    func testProofHomeModelInputs() {
        let store = store()
        let property = Self.property
        measure {
            for _ in 0..<Self.iterations {
                _ = store.documentedRoomCount(for: property)
                _ = store.totalRoomCount(for: property)
                _ = store.totalPhotoCount(for: property)
                _ = store.uploadedSupportingRecordCount(for: property)
                _ = store.openIssueCount(for: property)
                _ = store.primaryNextAction(for: property)            // vaultNextRoomName
                _ = store.primaryNextAction(for: property)            // featuredContinueProofTitle
                _ = store.missingSupportingRecordCount(for: property)
                _ = store.isExportReady(for: property)
                _ = store.readinessScore(for: property)
                _ = store.lifecycleNudge(for: property)
                let recent = property.rooms.compactMap { room -> (Date, Int)? in
                    guard let latest = room.evidence.filter({ !$0.photos.isEmpty }).max(by: { $0.createdAt < $1.createdAt }) else { return nil }
                    return (latest.createdAt, room.moveInPhotoTotal)
                }
                _ = recent.sorted { $0.0 > $1.0 }
            }
        }
    }

    /// The rental record and room list map every room to its row.
    func testRentalRoomRows() {
        measure {
            for _ in 0..<Self.iterations {
                _ = Self.property.rooms.map { MMRentalRoom($0) }
                _ = Self.property.rooms.first { !MMRoomProofMetrics.isDocumented($0) }
            }
        }
    }

    /// Move-out compares every room on each render.
    func testMoveOutComparisons() {
        measure {
            for _ in 0..<Self.iterations {
                _ = Self.property.rooms.map { MoveOutComparison.make(room: $0) }
            }
        }
    }

    /// The dispute packet model over the whole rental and 100 cases.
    func testDisputePacketModel() {
        let selected = Set(Self.rooms.prefix(20).map(\.id))
        measure {
            for _ in 0..<Self.iterations {
                _ = DisputePacketModel.make(property: Self.property, maintenance: Self.cases, exports: [], readyIDs: [], activeIDs: [],
                                            failedIDs: [], selectedRoomIDs: selected, hasPro: true)
            }
        }
    }

    /// The room hero and viewer order and caption every photo of a room (here: all 300 in one list).
    func testViewerOrderingAndCaptions() {
        let entries = Self.rooms.flatMap(\.evidence)
        measure {
            for _ in 0..<Self.iterations {
                _ = RoomEvidenceHero.orderedPhotos(entries)
                _ = RoomPhotoViewer.captions(for: entries)
            }
        }
    }
}
