//
//  MaintenanceCaseSnapshotTests.swift
//  movemorkTests
//
//  @file Goldens for Maintenance as a case file (the case log, the issue case — open, resolved, no photos,
//        error, loading, not found) and the dark evidence viewer (room photos with their record, maintenance
//        photos), on the Pro phone, the small phone and AX3. Photos come from Fixtures/snap-*.jpg through
//        mmEvidenceImageOverride, so renders are deterministic and show real evidence material.
//  @domain design-system
//  @see [[MMSystem+Maintenance.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class MaintenanceCaseSnapshotTests: XCTestCase {
    private static let propertyID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-000000000001")!
    private static let userID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-000000000002")!
    private static let issueID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-0000000000AA")!

    private var devices: [(String, ViewImageConfig)] { ScreenSnapshot.allDevices }

    // MARK: Fixtures

    /// A local wall-clock time in 2026, so goldens read the same in any time zone.
    private static func local(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    private static func photo(_ name: String) -> UIImage? {
        guard let url = Bundle(for: MaintenanceCaseSnapshotTests.self).url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static let fixturePhotos: (String) -> UIImage? = { path in
        photo((path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path)
    }

    private func withPhotos<V: View>(_ view: V) -> some View {
        view.environment(\.mmEvidenceImageOverride, Self.fixturePhotos)
    }

    private func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "6F1E2C3D-0000-4000-8000-%012d", 300 + n))! }

    private var caseFiles: [EvidenceFileRow] {
        ["snap-kitchen", "snap-living", "snap-bedroom", "snap-hero"].enumerated().map { index, name in
            EvidenceFileRow(id: id(index), propertyId: Self.propertyID, maintenanceIssueId: Self.issueID,
                            filePath: "fixture/\(name).jpg", fileType: "image",
                            capturedAt: Self.iso(Self.local(10, 26, 8, 30 + index * 3)),
                            createdAt: Self.iso(Self.local(10, 26, 8, 40 + index)))
        }
    }

    private func issue(resolved: Bool = false, followUp: Bool = true) -> MaintenanceIssueRow {
        MaintenanceIssueRow(
            id: Self.issueID, propertyId: Self.propertyID, userId: Self.userID,
            title: "Water leak under sink",
            description: "Water pooling in the cabinet under the kitchen sink after each use. The base panel is swelling and the trap joint drips when the tap runs.",
            category: "Plumbing", status: resolved ? "resolved" : "open",
            dateDiscovered: Self.iso(Self.local(10, 26, 8, 15)), dateReported: Self.iso(Self.local(10, 26, 8, 42)),
            reportMethod: nil,
            landlordResponse: followUp ? "Emailed the property manager with the photos. A plumber is booked for Thursday morning." : nil,
            followUpDate: followUp ? Self.iso(Self.local(10, 26, 9, 10)) : nil,
            updatedAt: resolved ? Self.iso(Self.local(10, 29, 11, 5)) : nil
        )
    }

    // MARK: Issue case

    func testCaseOpen() {
        assertScreen(withPhotos(MaintenanceIssueDetailView(issue: issue(), initialEvidence: caseFiles)), devices: devices)
    }

    /// The whole case page in one image (timeline, details, composer, Mark resolved) for review.
    func testCaseOpenFullPage() {
        assertScreen(withPhotos(MaintenanceIssueDetailView(issue: issue(), initialEvidence: caseFiles)), devices: [("tall", Self.tall)])
    }

    func testLogFullPage() {
        assertScreen(withPhotos(MaintenanceLogView(path: .constant([]), initialCovers: covers).environment(logStore(log))),
                     devices: [("tall", Self.tall)])
    }

    private static let tall = ViewImageConfig(safeArea: ScreenSnapshot.pro.safeArea, size: CGSize(width: 402, height: 2300),
                                              traits: ScreenSnapshot.pro.traits)

    func testCaseResolved() {
        assertScreen(withPhotos(MaintenanceIssueDetailView(issue: issue(resolved: true), initialEvidence: caseFiles)),
                     devices: [("pro", ScreenSnapshot.pro), ("small", ScreenSnapshot.small)])
    }

    func testCaseOnePhotoNoFollowUp() {
        assertScreen(withPhotos(MaintenanceIssueDetailView(issue: issue(followUp: false), initialEvidence: Array(caseFiles.prefix(1)))))
    }

    func testCaseNoPhotos() {
        assertScreen(MaintenanceIssueDetailView(issue: issue(followUp: false), initialEvidence: []), devices: devices)
    }

    func testCaseError() {
        assertScreen(withPhotos(MaintenanceIssueDetailView(issue: issue(), initialError: "Couldn’t save follow-up. Check your connection and try again.",
                                                           initialEvidence: caseFiles)))
    }

    func testCaseNotFound() {
        assertScreen(MaintenanceIssueDetailContainerView(issueID: UUID(), initialError: MoveMarkFlowMessage.maintenanceIssueNotFound),
                     devices: devices)
    }

    func testCaseLoading() {
        // A real property makes the container wait on the network lookup, so the loading state holds.
        let store = PropertyStore()
        store.currentProperty = PropertyRecord(id: Self.propertyID, title: "88 Harbour St", addressLine1: "88 Harbour St",
                                               moveInDate: Self.local(9, 1, 9, 0), leaseEndDate: Self.local(9, 1, 9, 0), rooms: [])
        assertScreen(MaintenanceIssueDetailContainerView(issueID: UUID()).environment(store))
    }

    // MARK: Case log

    private func logStore(_ log: [MaintenanceRecord]) -> PropertyStore {
        let store = PropertyStore()
        store.maintenanceLog = log
        return store
    }

    private var log: [MaintenanceRecord] {
        [
            MaintenanceRecord(id: Self.issueID, title: "Water leak under sink", category: "Plumbing",
                              details: "Water pooling in the cabinet under the kitchen sink.",
                              status: .open, createdAt: Self.local(10, 26, 8, 42), photoCount: 4),
            MaintenanceRecord(id: id(20), title: "Bedroom window won't latch", category: "Structural", details: "",
                              status: .followUp, createdAt: Self.local(10, 20, 18, 5), photoCount: 0),
            MaintenanceRecord(id: id(21), title: "Dishwasher not draining", category: "Appliance", details: "Replaced pump.",
                              status: .resolved, createdAt: Self.local(9, 24, 10, 0), photoCount: 2),
        ]
    }

    private var covers: [UUID: EvidencePhoto] {
        [Self.issueID: EvidencePhoto(id: id(0), filePath: "fixture/snap-kitchen.jpg"),
         id(21): EvidencePhoto(id: id(30), filePath: "fixture/snap-living.jpg")]
    }

    func testLogPopulated() {
        assertScreen(withPhotos(MaintenanceLogView(path: .constant([]), initialCovers: covers).environment(logStore(log))), devices: devices)
    }

    func testLogEmpty() {
        assertScreen(MaintenanceLogView(path: .constant([])).environment(logStore([])), devices: devices)
    }

    func testLogLoading() {
        assertScreen(MaintenanceLogView(path: .constant([]), initiallyLoading: true).environment(logStore([])))
    }

    func testLogError() {
        assertScreen(withPhotos(MaintenanceLogView(path: .constant([]), initialError: MoveMarkFlowMessage.maintenanceListSyncFailed,
                                                   initialCovers: covers).environment(logStore(log))),
                     devices: [("pro", ScreenSnapshot.pro), ("small", ScreenSnapshot.small)])
    }

    // MARK: Evidence viewer

    private var roomEntries: [EvidenceRecord] {
        [
            EvidenceRecord(id: id(40), title: "North wall", notes: "Two scratches beside the window frame, about 10 cm long.",
                           issueTags: ["Scratch", "Chipped paint"], condition: .fair, createdAt: Self.local(10, 24, 15, 18),
                           photoCount: 2,
                           photos: [EvidencePhoto(id: id(41), filePath: "fixture/snap-living.jpg"),
                                    EvidencePhoto(id: id(42), filePath: "fixture/snap-hero.jpg")],
                           stage: .moveIn),
            EvidenceRecord(id: id(43), title: "", notes: "", issueTags: [], condition: .good, createdAt: Self.local(10, 24, 15, 2),
                           photoCount: 1, photos: [EvidencePhoto(id: id(44), filePath: "fixture/snap-bedroom.jpg")], stage: .moveIn),
        ]
    }

    func testRoomViewer() {
        let photos = roomEntries.flatMap(\.photos)
        assertScreen(withPhotos(RoomPhotoViewer(photos: photos, startID: photos[0].id, subject: "Living Room",
                                                captions: RoomPhotoViewer.captions(for: roomEntries),
                                                resolvePhotoURL: { _ in nil }, onClose: {})),
                     devices: devices, inNavigation: false)
    }

    func testRoomViewerPlainEntry() {
        let photos = roomEntries.flatMap(\.photos)
        assertScreen(withPhotos(RoomPhotoViewer(photos: photos, startID: photos[2].id, subject: "Living Room",
                                                captions: RoomPhotoViewer.captions(for: roomEntries),
                                                resolvePhotoURL: { _ in nil }, onClose: {})),
                     inNavigation: false)
    }

    func testMaintenanceViewer() {
        let photos = caseFiles.map { EvidencePhoto(id: $0.id, filePath: $0.filePath) }
        let captions = Dictionary(uniqueKeysWithValues: caseFiles.map {
            ($0.id, RoomPhotoViewer.Caption(phase: "Maintenance", date: MMCaseDate.parse($0.capturedAt)?.date, dateVerb: "Captured"))
        })
        assertScreen(withPhotos(RoomPhotoViewer(photos: photos, startID: photos[3].id, subject: "Water leak under sink",
                                                captions: captions, resolvePhotoURL: { _ in nil }, onClose: {})),
                     inNavigation: false)
    }
}
