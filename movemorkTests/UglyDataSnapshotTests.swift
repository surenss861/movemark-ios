//
//  UglyDataSnapshotTests.swift
//  movemorkTests
//
//  @file Hostile real-world data on the main screens: a 45-character rental name, a long street with unit
//        "PH-12B / Rear", no city, no unit, 20- and 30-room rentals, a 40-character room name, 0 and 300 photos
//        (counts only; the four fixture photos are reused), 25 maintenance cases, 1,500-character notes, a
//        one-character name, an 80-character email, report titles that wrap to three lines and pseudo-translated
//        user text. Pro phone, small phone and AX3. These pin that nothing clips, overlaps or blows up; they are
//        not design goldens.
//  @domain design-system
//  @see [[ScreenSnapshotTests.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class UglyDataSnapshotTests: XCTestCase {
    private var devices: [(String, ViewImageConfig)] { ScreenSnapshot.allDevices }

    private static func tall(_ height: CGFloat, ax: Bool = false) -> ViewImageConfig {
        ViewImageConfig(safeArea: ScreenSnapshot.pro.safeArea, size: CGSize(width: 402, height: height),
                        traits: ax ? ScreenSnapshot.proAX.traits : ScreenSnapshot.pro.traits)
    }

    // MARK: Hostile strings

    static let rentalName = "Harbourfront Lofts Residence at Queens Quay W"                     // 45
    static let street = "1234 Lakeshore Boulevard West Service Road North"
    static let unit = "PH-12B / Rear"
    static let longRoom = "Primary Bedroom Walk-In Closet & Ensuite"                            // 40
    static let email = "alexandra.konstantinopoulou-vandenberg.moving.026@property-management-example.ca"   // 80
    static let pseudoTitle = "[Ŵåţéŕ ļéåķîñĝ ûñðéŕ ţĥé ķîţçĥéñ šîñķ çåƀîñéţ – ŏñé ţŵŏ ţĥŕéé fôûŕ fîvé]"
    static let pseudoTag = "[Šçŕåţçĥéð ƥåîñţ ñéåŕ ŵîñðŏŵ – ŏñé ţŵŏ]"
    static let notes1500: String = {
        let sentence = "Water damage along the baseboard beside the window; paint is bubbling and the trim has lifted about 2 cm. "
        var text = ""
        while text.count < 1500 { text += sentence }
        return String(text.prefix(1500))
    }()
    static let reportTitle = "Move-in report — Harbourfront Lofts Residence at Queens Quay W, PH-12B / Rear entrance"

    func testFixtureStringsAreAsHostileAsAdvertised() {
        XCTAssertEqual(Self.rentalName.count, 45)
        XCTAssertEqual(Self.longRoom.count, 40)
        XCTAssertEqual(Self.email.count, 80)
        XCTAssertEqual(Self.notes1500.count, 1500)
    }

    // MARK: Fixtures

    private static let day = Date(timeIntervalSince1970: 1_760_900_000)   // Oct 19 2025

    private static func photo(_ name: String) -> UIImage? {
        guard let url = Bundle(for: UglyDataSnapshotTests.self).url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static let fixtureNames = ["snap-living", "snap-hero", "snap-kitchen", "snap-bedroom"]

    private static let images: (String) -> UIImage? = { path in
        photo((path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path)
    }

    private func withPhotos<V: View>(_ view: V) -> some View {
        view.environment(\.mmEvidenceImageOverride, Self.images)
    }

    private static func uuid(_ group: Int, _ n: Int) -> UUID {
        UUID(uuidString: String(format: "0BAD0000-0000-4000-%04d-%012d", group, n))!
    }

    /// Up to four real photo rows (fixture images); `photoCount` carries the hostile count.
    private static func photos(_ count: Int, seed: Int) -> [EvidencePhoto] {
        (0..<min(count, 4)).map { EvidencePhoto(id: uuid(9, seed * 10 + $0), filePath: "fixture/\(fixtureNames[$0 % 4]).jpg") }
    }

    private static func entry(_ n: Int, photos count: Int, notes: String = "", tags: [String] = [],
                              stage: EvidenceRecord.Stage = .moveIn, title: String = "Walls") -> EvidenceRecord {
        EvidenceRecord(id: uuid(8, n), title: title, notes: notes, issueTags: tags, condition: .fair, createdAt: day,
                       photoCount: count, photos: photos(count, seed: n), stage: stage)
    }

    static let roomNames = ["Kitchen", "Living Room", longRoom, "Second Bedroom", "Bathroom", "Balcony", "Ensuite",
                            "Hallway", "Closet", "Laundry", "Den", "Office", "Powder Room", "Mudroom", "Pantry",
                            "Storage Locker", "Parking Spot P2-114", "Guest Bedroom", "Dining Room", "Foyer",
                            "Sunroom", "Rooftop Terrace", "Workshop", "Nursery", "Gym", "Media Room", "Wine Cellar",
                            "Attic", "Basement", "Garage"]

    /// `count` rooms; the first ~two thirds documented, the 40-char room is documented with 300 photos.
    private static func rooms(_ count: Int, moveOut: Bool = false) -> [RoomRecord] {
        (0..<count).map { i in
            let name = roomNames[i % roomNames.count]
            let documented = i < (count * 2 / 3)
            let photoCount = name == longRoom ? 300 : (documented ? 3 + i % 5 : 0)
            let tags = i % 4 == 0 && documented ? [pseudoTag] : []
            return RoomRecord(
                id: uuid(1, i), name: name,
                evidence: photoCount > 0 ? [entry(i, photos: photoCount, notes: i == 2 ? notes1500 : "", tags: tags)] : [],
                moveOutEvidence: moveOut && documented ? [entry(100 + i, photos: 2 + i % 3, tags: i % 3 == 0 ? ["Stain"] : [],
                                                                stage: .moveOut)] : []
            )
        }
    }

    private static func rental(rooms: [RoomRecord], title: String = rentalName, street: String = street,
                               unit: String = unit, city: String? = "Toronto", documents: [String] = ["lease"]) -> PropertyRecord {
        PropertyRecord(
            id: UUID(uuidString: "0BAD0000-1111-2222-3333-444444444444")!,
            title: title, addressLine1: street, addressLine2: unit,
            city: city ?? "", provinceState: city == nil ? "" : "ON", postalCode: "M5J 2N8",
            landlordName: "Konstantinopoulou-Vandenberg Property Management Group Inc.",
            landlordEmail: email,
            moveInDate: day, leaseStartDate: day, leaseEndDate: day.addingTimeInterval(365 * 86_400),
            depositAmount: "1500", rentAmount: "2400", country: "CA",
            rooms: rooms, vaultDocuments: documents
        )
    }

    // MARK: Proof home

    private func proofModel(rooms: Int, photos: Int, name: String = rentalName, address: String? = "\(unit) · Toronto, ON")
        -> ProofHomeModel {
        let all = Self.rooms(max(rooms, 1))
        let documented = photos == 0 ? 0 : all.filter { !$0.evidence.isEmpty }.count
        let recent: [ProofHomeModel.Recent] = photos == 0 ? [] : all.filter { !$0.evidence.isEmpty }.prefix(8).enumerated().map { i, r in
            .init(id: r.id, roomName: r.name, photoCount: r.moveInPhotoTotal, photoPath: "fixture/\(Self.fixtureNames[i % 4]).jpg")
        }
        let upcoming = (photos == 0 ? all : all.filter { $0.evidence.isEmpty }).map { ProofHomeModel.Upcoming(id: $0.id, roomName: $0.name) }
        let actions: [ProofHomeModel.Action] = [
            .init(id: "lease", kind: .document(.lease), title: "Lease", subtitle: "Add your lease agreement", icon: "doc.text", needed: true),
            .init(id: "maintenance", kind: .maintenance, title: "Maintenance issue", subtitle: "25 open issues", icon: "wrench.adjustable"),
        ]
        return ProofHomeModel(
            propertyName: name, addressLine: address,
            documented: documented, totalRooms: rooms,
            nextRoomName: upcoming.first?.roomName, primaryTitle: "Capture \(upcoming.first?.roomName ?? "")",
            photos: photos, records: 1, issues: 25,
            recent: recent, upcoming: upcoming, actions: actions,
            otherRentals: [.init(id: Self.uuid(2, 1), name: "\(Self.street), \(Self.unit)", status: "0 of 30 rooms ready · Start move-in proof")]
        )
    }

    private func proofScreen(_ model: ProofHomeModel) -> some View {
        withPhotos(ProofHomeView(model: model, resolvePhotoURL: { _ in nil })
            .safeAreaInset(edge: .bottom, spacing: 0) { MMRootDock(selectedTab: .constant(.vaults)) })
    }

    func testProof30Rooms300Photos() {
        assertScreen(proofScreen(proofModel(rooms: 30, photos: 300)), devices: devices + [("tall", Self.tall(2000))],
                     inNavigation: false)
    }

    func testProof20RoomsNoPhotosNoCity() {
        assertScreen(proofScreen(proofModel(rooms: 20, photos: 0, address: nil)), devices: devices, inNavigation: false)
    }

    // MARK: Rental record

    private func vaultModel(_ property: PropertyRecord) -> PropertyVaultModel {
        var model = PropertyVaultModel(
            title: PropertyVaultModel.displayTitle(for: property),
            addressLine: PropertyVaultModel.addressLine(for: property),
            moveInLine: PropertyVaultModel.moveInLine(for: property, now: Self.day.addingTimeInterval(86_400)),
            rooms: property.rooms.map { MMRentalRoom($0) },
            nextRoomID: property.rooms.first { !MMRoomProofMetrics.isDocumented($0) }?.id,
            records: [VaultDocumentType.lease, .depositReceipt, .listingScreenshot, .other].map { type in
                let present = property.vaultDocuments.contains(type.rawValue)
                return .init(type: type, isPresent: present, addedOn: present ? "Oct 17, 2025" : nil,
                             file: present ? "harbourfront-lofts-residence-queens-quay-w-ph-12b-rear-tenancy-agreement-2025-signed-final-v3.pdf" : nil)
            },
            details: PropertyVaultModel.Detail.primary(for: property),
            moreDetails: PropertyVaultModel.Detail.more(for: property)
        )
        model.maintenance = .init(open: 25, total: 100)
        model.moveOut = .init(documented: 7, total: 30)
        return model
    }

    private func vault(_ property: PropertyRecord, expanded: Bool = false) -> some View {
        PropertyVaultContent(model: vaultModel(property), showAllRecords: .constant(expanded), showDetails: .constant(expanded))
    }

    func testRental30RoomsLongNameAndUnit() {
        assertScreen(vault(Self.rental(rooms: Self.rooms(30))),
                     devices: devices + [("tall", Self.tall(2400)), ("tall-ax3", Self.tall(4200, ax: true))])
    }

    func testRentalNoCityNoUnitExpanded() {
        assertScreen(vault(Self.rental(rooms: Self.rooms(20), unit: "", city: nil), expanded: true),
                     devices: [("pro", ScreenSnapshot.pro), ("small", ScreenSnapshot.small), ("tall", Self.tall(2600))])
    }

    func testRentalUntitledNoRooms() {
        assertScreen(vault(Self.rental(rooms: [], title: "", unit: "", city: nil, documents: [])), devices: devices)
    }

    // MARK: Room list

    func testRoomList30Rooms() {
        let store = PropertyStore()
        store.currentProperty = Self.rental(rooms: Self.rooms(30))
        assertScreen(RoomListView(path: .constant([])).environment(store), devices: devices + [("tall", Self.tall(2600))])
    }

    // MARK: Room

    private func roomScreen(name: String, entries: [EvidenceRecord]) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RoomEvidenceHero(roomName: name, entries: entries, moveOutMode: false,
                                     topInset: geo.safeAreaInsets.top, containerSize: geo.size, resolvePhotoURL: { _ in nil })
                    if !entries.isEmpty {
                        RoomEvidenceBody(entries: entries, moveOutMode: false, isBusy: false,
                                         onEdit: { _ in }, onAddPhotos: { _ in }, onDelete: { _ in })
                            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(MoveMarkTheme.Colors.appBackground)
        .environment(\.colorScheme, .dark)
    }

    func testRoomLongName300PhotosLongNotes() {
        let entries = [Self.entry(1, photos: 300, notes: Self.notes1500, tags: [Self.pseudoTag, "Chipped paint", "Stain"],
                                  title: Self.pseudoTitle),
                       Self.entry(2, photos: 1)]
        assertScreen(withPhotos(roomScreen(name: Self.longRoom, entries: entries)),
                     devices: devices + [("tall", Self.tall(2400))], inNavigation: false)
    }

    func testRoomLongNameEmpty() {
        assertScreen(roomScreen(name: Self.longRoom, entries: []), devices: devices, inNavigation: false)
    }

    // MARK: Edit evidence / viewer

    func testEditEvidenceLongNotes() {
        let record = Self.entry(3, photos: 300, notes: Self.notes1500, tags: [Self.pseudoTag, "Scratch", "Chipped paint"],
                                title: Self.pseudoTitle)
        assertScreen(withPhotos(EditEvidenceSheet(evidence: record, roomName: Self.longRoom, onSave: { _, _, _, _ in nil },
                                                  onDelete: {}, onDismiss: {})),
                     devices: devices, inNavigation: false)
    }

    func testViewerLongCaption() {
        // All 300 photos as models here (other tests cap at four), so the counter reads "1 of 300" and the
        // filmstrip is really 300 long.
        let all = (0..<300).map { EvidencePhoto(id: Self.uuid(9, 4000 + $0), filePath: "fixture/\(Self.fixtureNames[$0 % 4]).jpg") }
        let entries = [EvidenceRecord(id: Self.uuid(8, 4), title: Self.pseudoTitle, notes: Self.notes1500,
                                      issueTags: [Self.pseudoTag, "Scratch"], condition: .fair, createdAt: Self.day,
                                      photoCount: 300, photos: all, stage: .moveIn)]
        let photos = entries.flatMap(\.photos)
        assertScreen(withPhotos(RoomPhotoViewer(photos: photos, startID: photos[0].id, subject: Self.longRoom,
                                                captions: RoomPhotoViewer.captions(for: entries),
                                                resolvePhotoURL: { _ in nil }, onClose: {})),
                     devices: devices, inNavigation: false)
    }

    // MARK: Maintenance

    private static func local(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private static var cases25: [MaintenanceRecord] {
        let titles = ["Water leak under sink", pseudoTitle, "Bedroom window won't latch", "Dishwasher not draining",
                      "Mould behind the bathroom vanity spreading toward the hallway closet door frame"]
        let statuses: [MaintenanceRecord.Status] = [.open, .followUp, .resolved]
        return (0..<25).map { i in
            MaintenanceRecord(id: uuid(3, i), title: titles[i % titles.count], category: i % 2 == 0 ? "Plumbing" : "Structural",
                              details: i == 0 ? notes1500 : "", status: statuses[i % 3],
                              createdAt: local(10, 26 - i % 26, 8, 0), photoCount: i % 3 == 0 ? 300 : i % 4)
        }
    }

    func testMaintenanceLog25Cases() {
        let store = PropertyStore()
        store.maintenanceLog = Self.cases25
        let covers = Dictionary(uniqueKeysWithValues: Self.cases25.enumerated().filter { $0.element.photoCount > 0 }.map {
            ($0.element.id, EvidencePhoto(id: Self.uuid(4, $0.offset), filePath: "fixture/\(Self.fixtureNames[$0.offset % 4]).jpg"))
        })
        assertScreen(withPhotos(MaintenanceLogView(path: .constant([]), initialCovers: covers).environment(store)),
                     devices: devices + [("tall", Self.tall(5200))])
    }

    private static let propertyID = UUID(uuidString: "0BAD0000-1111-2222-3333-444444444444")!

    private var longIssue: MaintenanceIssueRow {
        MaintenanceIssueRow(
            id: Self.uuid(5, 1), propertyId: Self.propertyID, userId: Self.uuid(5, 2),
            title: Self.pseudoTitle, description: Self.notes1500, category: "Plumbing", status: "open",
            dateDiscovered: ISO8601DateFormatter().string(from: Self.local(10, 26, 8, 15)),
            dateReported: ISO8601DateFormatter().string(from: Self.local(10, 26, 8, 42)), reportMethod: nil,
            landlordResponse: Self.notes1500, followUpDate: ISO8601DateFormatter().string(from: Self.local(10, 26, 9, 10)),
            updatedAt: nil
        )
    }

    private var caseFiles: [EvidenceFileRow] {
        (0..<4).map { i in
            EvidenceFileRow(id: Self.uuid(6, i), propertyId: Self.propertyID, maintenanceIssueId: Self.uuid(5, 1),
                            filePath: "fixture/\(Self.fixtureNames[i]).jpg", fileType: "image",
                            capturedAt: ISO8601DateFormatter().string(from: Self.local(10, 26, 8, 30 + i)),
                            createdAt: ISO8601DateFormatter().string(from: Self.local(10, 26, 8, 40 + i)))
        }
    }

    func testMaintenanceCaseLongText() {
        assertScreen(withPhotos(MaintenanceIssueDetailView(issue: longIssue, initialEvidence: caseFiles)),
                     devices: devices + [("tall", Self.tall(3600))])
    }

    // MARK: Reports

    private func reportsScreen() -> some View {
        let day = Date(timeIntervalSince1970: 1_761_510_540)
        var m = ReportsHomeModel(rentalName: Self.rentalName, documented: 20, totalRooms: 30, photos: 300, records: 3, issues: 25,
                                 primary: .ready(generatedAt: day))
        m.others = [.init(id: "move_out", title: "Move-out report", detail: Self.pseudoTitle),
                    .init(id: "dispute", title: "Dispute packet", detail: "Ready to generate")]
        m.history = (0..<6).map { i in
            .init(id: Self.uuid(7, i), title: i % 2 == 0 ? Self.reportTitle : Self.pseudoTitle,
                  date: day.addingTimeInterval(Double(-86_400 * i)), status: i == 1 ? .failed : .ready, canRetry: i == 1)
        }
        return ReportsHomeView(model: m)
            .environment(\.mmRootTabBarVisible, true)
            .safeAreaInset(edge: .bottom, spacing: 0) { MMRootDock(selectedTab: .constant(.exports)) }
    }

    func testReportsLongTitles() {
        assertScreen(reportsScreen(), devices: devices + [("tall", Self.tall(2200))], inNavigation: false)
    }

    // MARK: Account

    private func accountScreen(name: String?, email: String) -> some View {
        AccountHomeView(model: AccountHomeModel(email: email, name: name, isPro: true, appVersion: "1.4 (6)"))
            .environment(\.mmRootTabBarVisible, true)
            .safeAreaInset(edge: .bottom, spacing: 0) { MMRootDock(selectedTab: .constant(.account)) }
    }

    func testAccountOneCharNameLongEmail() {
        assertScreen(accountScreen(name: "S", email: Self.email), devices: devices, inNavigation: false)
    }

    func testEditNameLong() {
        assertScreen(EditNameSheet(currentName: "S", onSave: { _ in }, draftName: Self.pseudoTitle), devices: devices, inNavigation: false)
    }

    // MARK: Move-out

    func testMoveOut30Rooms() {
        let store = PropertyStore()
        store.currentProperty = Self.rental(rooms: Self.rooms(30, moveOut: true))
        assertScreen(withPhotos(MoveOutFoundationView(path: .constant([])).environment(store)),
                     devices: devices + [("tall", Self.tall(9000))])
    }

    // MARK: Dispute packet

    func testDisputePacket30Rooms() {
        let rooms = Self.rooms(30, moveOut: true)
        let property = Self.rental(rooms: rooms, documents: ["lease", "deposit_receipt"])
        let model = DisputePacketModel.make(property: property, maintenance: Self.cases25, exports: [], readyIDs: [], activeIDs: [],
                                            failedIDs: [], selectedRoomIDs: Set(rooms.prefix(20).map(\.id)), hasPro: true)
        assertScreen(withPhotos(DisputePacketContent(model: model, question: .constant(Self.notes1500),
                                                     amount: .constant("$12,345,678.90"))),
                     devices: devices + [("tall", Self.tall(6000))])
    }

    // MARK: Forms

    func testEditRentalLongValues() {
        assertScreen(EditPropertyView(property: Self.rental(rooms: Self.rooms(30)))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") {} } },
                     devices: devices + [("tall", Self.tall(2000))])
    }
}
