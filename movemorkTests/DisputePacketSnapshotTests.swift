//
//  DisputePacketSnapshotTests.swift
//  movemorkTests
//
//  @file Goldens for the evidence packet builder: ready to generate (a changed room and an unchanged room involved,
//        records included, missing proof), generated (view / share), generating, and a rental without move-in proof
//        — on the Pro phone, the small phone and AX3, plus a tall full page. Also pins what the model counts.
//  @domain dispute
//  @see [[DisputePacketContent.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class DisputePacketSnapshotTests: XCTestCase {
    private static let moveInDay = Date(timeIntervalSince1970: 1_761_510_540)      // Oct 26, 2025
    private static let moveOutDay = Date(timeIntervalSince1970: 1_777_550_400)     // Apr 30, 2026
    private static let propertyID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-0000000000D1")!
    private static let userID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-0000000000D2")!

    private static func photo(_ name: String) -> UIImage? {
        guard let url = Bundle(for: DisputePacketSnapshotTests.self).url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static func photos(_ name: String, _ count: Int, seed: Int) -> [EvidencePhoto] {
        (0..<count).map { i in
            EvidencePhoto(id: UUID(uuidString: String(format: "6F1E2C3D-0000-4000-8002-%012d", seed * 100 + i))!,
                          filePath: "fixture/\(name).jpg")
        }
    }

    private static func entry(_ notes: String = "", tags: [String] = [], _ condition: RoomRecord.ConditionRating,
                              stage: EvidenceRecord.Stage, photo: String, count: Int, seed: Int) -> EvidenceRecord {
        EvidenceRecord(title: "", notes: notes, issueTags: tags, condition: condition,
                       createdAt: stage == .moveOut ? moveOutDay : moveInDay, photoCount: count,
                       photos: photos(photo, min(count, 2), seed: seed), stage: stage)
    }

    private static func room(_ n: Int, _ name: String, moveIn: [EvidenceRecord] = [], moveOut: [EvidenceRecord] = []) -> RoomRecord {
        RoomRecord(id: UUID(uuidString: String(format: "6F1E2C3D-0000-4000-8003-%012d", n))!, name: name,
                   evidence: moveIn, moveOutEvidence: moveOut)
    }

    private static var rooms: [RoomRecord] {
        [
            room(1, "Kitchen",
                 moveIn: [entry("Counters and cabinet doors intact", .good, stage: .moveIn, photo: "snap-kitchen", count: 5, seed: 1)],
                 moveOut: [entry("Ring mark near the sink", tags: ["Stain"], .good, stage: .moveOut, photo: "snap-kitchen", count: 3, seed: 2)]),
            room(2, "Living Room",
                 moveIn: [entry("Walls clean", .good, stage: .moveIn, photo: "snap-living", count: 4, seed: 3)],
                 moveOut: [entry("Walls clean", .good, stage: .moveOut, photo: "snap-living", count: 2, seed: 4)]),
            room(3, "Bedroom",
                 moveIn: [entry("Carpet even", .good, stage: .moveIn, photo: "snap-bedroom", count: 3, seed: 5)]),
        ]
    }

    private static func property(rooms: [RoomRecord], documents: [String]) -> PropertyRecord {
        var property = PropertyRecord(id: propertyID, title: "88 Harbour St", addressLine1: "88 Harbour St",
                                      moveInDate: moveInDay, leaseEndDate: moveOutDay, rooms: rooms)
        property.vaultDocuments = documents
        return property
    }

    private static let maintenance = [
        MaintenanceRecord(title: "Water leak under sink", category: "Plumbing", details: "", status: .resolved,
                          createdAt: moveInDay.addingTimeInterval(86_400 * 40), photoCount: 3),
    ]

    private static func export(_ n: Int, _ type: String, at iso: String) -> ExportRow {
        ExportRow(id: UUID(uuidString: String(format: "6F1E2C3D-0000-4000-8004-%012d", n))!, disputeId: nil,
                  propertyId: propertyID, userId: userID, exportType: type, filePath: "exports/\(n).pdf", createdAt: iso)
    }

    private static let moveInReport = export(1, "move_in_report", at: "2025-10-27T15:00:00Z")
    private static let packetRow = export(2, "dispute_packet", at: "2026-05-02T16:20:00Z")

    private func model(rooms: [RoomRecord]? = nil, documents: [String] = ["lease"],
                       exports: [ExportRow]? = nil, ready: Set<UUID>? = nil,
                       active: Set<UUID> = [], selected: Set<UUID>? = nil, hasPro: Bool = true) -> DisputePacketModel {
        let rooms = rooms ?? Self.rooms
        let exports = exports ?? [Self.moveInReport]
        return DisputePacketModel.make(
            property: Self.property(rooms: rooms, documents: documents), maintenance: rooms.isEmpty ? [] : Self.maintenance,
            exports: exports, readyIDs: ready ?? Set(exports.map(\.id)).subtracting(active), activeIDs: active, failedIDs: [],
            selectedRoomIDs: selected ?? Set(rooms.prefix(2).map(\.id)), hasPro: hasPro
        )
    }

    private func screen(_ model: DisputePacketModel, question: String = "Deduction for the kitchen counter",
                        amount: String = "$350") -> some View {
        DisputePacketContent(model: model, question: .constant(question), amount: .constant(amount))
            .environment(\.mmEvidenceImageOverride, { path in
                Self.photo((path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path)
            })
    }

    private let tall = ViewImageConfig(safeArea: ScreenSnapshot.pro.safeArea, size: CGSize(width: 402, height: 3000),
                                       traits: ScreenSnapshot.pro.traits)

    // MARK: Screens

    func testPacketReady() {
        assertScreen(screen(model()), devices: ScreenSnapshot.allDevices)
    }

    func testPacketReadyFullPage() {
        assertScreen(screen(model()), devices: [("tall", tall)])
    }

    func testPacketGenerated() {
        let exports = [Self.moveInReport, Self.packetRow]
        assertScreen(screen(model(documents: ["lease", "deposit_receipt"], exports: exports)), devices: [("tall", tall)])
    }

    func testPacketGenerating() {
        let exports = [Self.moveInReport, Self.packetRow]
        assertScreen(screen(model(exports: exports, active: [Self.packetRow.id])), devices: [("tall", tall)])
    }

    func testPacketFreePlanEmptyNote() {
        assertScreen(screen(model(selected: [], hasPro: false), question: "", amount: ""), devices: [("tall", tall)])
    }

    func testPacketNeedsMoveInProof() {
        let rooms = [Self.room(1, "Kitchen"), Self.room(2, "Living Room")]
        assertScreen(screen(model(rooms: rooms, documents: [], exports: [], selected: []), question: "", amount: ""),
                     devices: [("pro", ScreenSnapshot.pro), ("small", ScreenSnapshot.small)])
    }

    // MARK: Model

    func testModelCountsWhatThePacketStates() {
        let m = model()
        XCTAssertEqual(m.moveInPhotos, 12)
        XCTAssertEqual(m.moveOutPhotos, 5)
        XCTAssertEqual(m.documents, 1)
        XCTAssertEqual(m.issues, 2)                       // "Stain" tag + one maintenance case
        XCTAssertTrue(m.moveInReportIncluded)
        XCTAssertEqual(m.packet, .ready)
        XCTAssertEqual(m.missing.map(\.id), ["deposit_receipt"])
        XCTAssertEqual(m.involved.map(\.state), [.newIssue, .unchanged])
    }

    func testModelNeedsMoveInProofWithoutRoomPhotos() {
        let m = model(rooms: [Self.room(1, "Kitchen")], documents: [], exports: [], selected: [])
        XCTAssertEqual(m.packet, .needsMoveInProof)
        XCTAssertEqual(m.missing.first?.id, "moveInProof")
    }
}
