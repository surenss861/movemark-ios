//
//  VisualSnapshotTests.swift
//  movemorkTests
//
//  @file Golden screenshots for redesigned screens: once a screen is approved, its snapshot is the
//        visual source of truth and any drift in spacing, type or geometry fails here
//  @domain design-system
//  @status wip
//  @see [[VISUAL_STANDARD]] — rollout and approval rules
//  @see [[ProofHomeView.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run once.
//
//  STATUS: Proof snapshots are CANDIDATES recorded from the reference-reproduction pass
//  (2026-10-20). They become approved goldens only when the user signs off the Proof screen.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class VisualSnapshotTests: XCTestCase {

    // MARK: Devices

    /// 6.3" iPhone Pro (402 × 874 pt, Dynamic Island).
    private static let pro = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 402, height: 874),
        traits: UITraitCollection(traitsFrom: [.init(displayScale: 3), .init(userInterfaceStyle: .light)])
    )

    /// Smallest supported phone (iPhone SE, 375 × 667 pt).
    private static let small = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0),
        size: CGSize(width: 375, height: 667),
        traits: UITraitCollection(traitsFrom: [.init(displayScale: 2), .init(userInterfaceStyle: .light)])
    )

    /// Pro size at AX3, the largest accessibility text size.
    private static let proAX = ViewImageConfig(
        safeArea: pro.safeArea,
        size: pro.size,
        traits: UITraitCollection(traitsFrom: [pro.traits, .init(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)])
    )

    private static let strategy: (ViewImageConfig) -> Snapshotting<UIViewController, UIImage> = {
        .image(on: $0, precision: 0.995, perceptualPrecision: 0.98)
    }

    // MARK: Fixtures

    private static func photo(_ name: String) -> UIImage? {
        guard let url = Bundle(for: VisualSnapshotTests.self).url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Evidence paths map to bundled photos so renders are synchronous and deterministic.
    private static let images: (String) -> UIImage? = { path in
        let name = (path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path
        return name == "text-heavy" ? textHeavy : photo(name)
    }

    /// A photo of a screen full of huge white text — the kind of evidence that once filled the Proof header.
    private static let textHeavy: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600)).image { ctx in
        UIColor(white: 0.12, alpha: 1).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
        ("LEASE\nUNIT 2304\nMOVE-IN" as NSString).draw(
            in: CGRect(x: 40, y: 80, width: 1120, height: 1500),
            withAttributes: [.font: UIFont.systemFont(ofSize: 260, weight: .black), .foregroundColor: UIColor.white])
    }

    private func host<V: View>(_ view: V) -> UIViewController {
        UIHostingController(rootView: view.environment(\.mmEvidenceImageOverride, Self.images))
    }

    private func proofModel(_ state: String) -> ProofHomeModel {
        let actions: [ProofHomeModel.Action] = [
            .init(id: "lease", kind: .document(.lease), title: "Lease", subtitle: "Add your lease agreement", icon: "doc.text", needed: true),
            .init(id: "deposit", kind: .document(.depositReceipt), title: "Deposit receipt", subtitle: "Upload proof of deposit", icon: "receipt", needed: true),
            .init(id: "listing", kind: .document(.listingScreenshot), title: "Listing proof", subtitle: "Save original listing", icon: "photo", needed: true),
            .init(id: "maintenance", kind: .maintenance, title: "Maintenance issue", subtitle: "Report existing issues", icon: "wrench.adjustable"),
        ]
        var m = ProofHomeModel(
            propertyName: "88 Harbour St", addressLine: "Unit 2304",
            documented: 9, totalRooms: 10,
            nextRoomName: "Primary Bedroom", primaryTitle: "Capture Primary Bedroom",
            photos: 12, records: 3, issues: 1,
            recent: [
                .init(id: UUID(), roomName: "Living Room", photoCount: 4, photoPath: "fixture/snap-living.jpg"),
                .init(id: UUID(), roomName: "Kitchen", photoCount: 3, photoPath: "fixture/snap-kitchen.jpg"),
                .init(id: UUID(), roomName: "Bedroom", photoCount: 3, photoPath: "fixture/snap-bedroom.jpg"),
            ],
            actions: actions, otherRentals: []
        )
        switch state {
        case "complete":
            m.documented = 10; m.nextRoomName = nil; m.primaryTitle = "View move-in report"
            m.actions = [actions[3], .init(id: "report", kind: .report, title: "Move-in report", subtitle: "Ready to share", icon: "doc.richtext")]
        case "one-room":
            // One documented room: the row keeps its rhythm with honest capture slots.
            m.documented = 1; m.photos = 2; m.issues = 0
            m.nextRoomName = "Living Room"; m.primaryTitle = "Capture Living Room"
            m.recent = [.init(id: UUID(), roomName: "Kitchen", photoCount: 2, photoPath: "fixture/snap-kitchen.jpg")]
            m.upcoming = [.init(id: UUID(), roomName: "Living Room"), .init(id: UUID(), roomName: "Primary Bedroom")]
        case "text-heavy":
            // The TestFlight case: 1 of 10, the newest evidence is a photo of large text.
            m.documented = 1; m.totalRooms = 10; m.photos = 1; m.records = 0; m.issues = 0
            m.propertyName = "My Apartment"; m.addressLine = "Toronto, ON"
            m.nextRoomName = "Living Room"; m.primaryTitle = "Capture Living Room"
            m.recent = [.init(id: UUID(), roomName: "Kitchen", photoCount: 1, photoPath: "fixture/text-heavy.jpg", capturedAt: Date())]
            m.upcoming = ["Living Room", "Primary Bedroom", "Bedroom 2", "Bathroom", "Hallway", "Laundry", "Balcony", "Entry", "Closet"]
                .map { .init(id: UUID(), roomName: $0) }
        case "no-photos":
            m.documented = 0; m.recent = []; m.photos = 0; m.issues = 0
            m.nextRoomName = "Kitchen"; m.primaryTitle = "Capture Kitchen"
        default: break
        }
        return m
    }

    private func proofScreen(_ state: String) -> some View {
        ProofHomeView(model: proofModel(state), resolvePhotoURL: { _ in nil })
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MMProofTabBarV4(selectedTab: .constant(.vaults))
            }
    }

    // MARK: Proof

    func testProofPopulated() {
        assertSnapshot(of: host(proofScreen("populated")), as: Self.strategy(Self.pro), named: "pro")
        assertSnapshot(of: host(proofScreen("populated")), as: Self.strategy(Self.small), named: "small")
        assertSnapshot(of: host(proofScreen("populated")), as: Self.strategy(Self.proAX), named: "ax3")
    }

    func testProofComplete() {
        assertSnapshot(of: host(proofScreen("complete")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testProofOneRoom() {
        assertSnapshot(of: host(proofScreen("one-room")), as: Self.strategy(Self.pro), named: "pro")
    }

    /// Evidence stays inside its own tile: nothing of the photo may reach the header or status bar.
    func testProofTextHeavyEvidenceStaysInItsTile() {
        assertSnapshot(of: host(proofScreen("text-heavy")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testProofNoPhotos() {
        assertSnapshot(of: host(proofScreen("no-photos")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testProofNoRental() {
        assertSnapshot(of: host(ProofHomeEmptyView(onStart: {}, onRetry: {})), as: Self.strategy(Self.pro), named: "pro")
    }

    // MARK: Saved proof receipt (after every room save)

    private func receiptScreen(photos: Int, pending: Int = 0, issues: Int = 0, next: String = "Continue to next room") -> UIViewController {
        let living = Bundle(for: VisualSnapshotTests.self).url(forResource: "snap-living", withExtension: "jpg")
        let savedAt = Calendar(identifier: .gregorian).date(from: DateComponents(
            timeZone: TimeZone(identifier: "America/Toronto"), year: 2026, month: 10, day: 24, hour: 15, minute: 18))!
        let model = ProofSavedReceiptModel(roomName: "Living Room", photoCount: photos, pendingCount: pending,
                                           issueCount: issues, savedAt: savedAt, imageURL: living, primaryActionLabel: next)
        let controller = host(ProofSavedReceiptView(model: model, onPrimary: {}, onSecondary: {},
                                                    onAddMorePhotos: pending > 0 ? nil : {}))
        // Let the photo load in a window before the snapshot.
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.pro.size ?? CGSize(width: 402, height: 874)))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        return controller
    }

    func testReceiptOnePhoto() {
        assertSnapshot(of: receiptScreen(photos: 1), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReceiptPhotosAndOneIssue() {
        assertSnapshot(of: receiptScreen(photos: 4, issues: 1), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReceiptPhotosAndIssues() {
        assertSnapshot(of: receiptScreen(photos: 4, issues: 3), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReceiptPartialSave() {
        assertSnapshot(of: receiptScreen(photos: 3, pending: 1, issues: 1, next: "Retry 1 photo"), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReceiptAllRoomsComplete() {
        assertSnapshot(of: receiptScreen(photos: 4, next: "View move-in report"), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReceiptLargestText() {
        assertSnapshot(of: receiptScreen(photos: 4, issues: 1), as: Self.strategy(Self.proAX), named: "ax3")
    }

    // MARK: Root dock (Proof · Reports · Account)

    private func dockScreen(_ tab: RootTab, dark: Bool) -> some View {
        // Content runs to the bottom so the floating dock is seen over it.
        LinearGradient(colors: dark ? [Color(white: 0.10), Color(white: 0.06)] : [Color(white: 0.97), Color(white: 0.90)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom, spacing: 0) { MMProofTabBarV4(selectedTab: .constant(tab)) }
    }

    func testDockProofOnLight() {
        assertSnapshot(of: host(dockScreen(.vaults, dark: false)), as: Self.strategy(Self.pro), named: "pro")
    }

    func testDockReportsOnDark() {
        assertSnapshot(of: host(dockScreen(.exports, dark: true)), as: Self.strategy(Self.pro), named: "pro")
    }

    func testDockAccountOnDark() {
        assertSnapshot(of: host(dockScreen(.account, dark: true)), as: Self.strategy(Self.pro), named: "pro")
    }

    func testDockLargestText() {
        assertSnapshot(of: host(dockScreen(.exports, dark: false)), as: Self.strategy(Self.proAX), named: "ax3")
        assertSnapshot(of: host(dockScreen(.vaults, dark: false)), as: Self.strategy(Self.small), named: "small")
    }

    // MARK: Camera (the chrome around the preview; the simulator has no camera feed)

    func testCameraChromeWithOnePhotoPending() {
        let camera = EvidenceCameraViewController(roomName: "Living Room", pendingCount: 1, prompts: RoomCapturePrompts.items,
                                                  onCapture: { _ in true }, onDone: {}, onCancel: {})
        assertSnapshot(of: camera, as: Self.strategy(Self.pro), named: "pro")
    }

    // MARK: Room (current dark design — regression only until Room is rebuilt and approved)

    private func roomScreen(entries: [EvidenceRecord], name: String) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RoomEvidenceHero(
                        roomName: name, entries: entries, moveOutMode: false,
                        topInset: geo.safeAreaInsets.top, containerSize: geo.size,
                        resolvePhotoURL: { _ in nil }
                    )
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

    func testRoomEmpty() {
        assertSnapshot(of: host(roomScreen(entries: [], name: "Balcony/Patio")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testRoomPopulated() {
        let recorded = Date(timeIntervalSince1970: 1_760_900_000)
        let entry = EvidenceRecord(
            title: "North wall", notes: "Two scratches beside the window.", issueTags: ["Scratch"],
            condition: .fair, createdAt: recorded, photoCount: 3,
            photos: ["snap-living", "snap-kitchen", "snap-bedroom"].map { EvidencePhoto(id: UUID(), filePath: "fixture/\($0).jpg") },
            stage: .moveIn
        )
        assertSnapshot(of: host(roomScreen(entries: [entry], name: "Living Room")), as: Self.strategy(Self.pro), named: "pro")
    }

    // MARK: Reports

    private static let reportDay = Date(timeIntervalSince1970: 1_761_510_540)   // Oct 26, fixed for goldens

    private func reportsModel(_ state: String) -> ReportsHomeModel {
        var m = ReportsHomeModel(rentalName: "88 Harbour St", documented: 10, totalRooms: 10, photos: 12, records: 3, issues: 1,
                                 primary: .ready(generatedAt: Self.reportDay))
        let moveOut = ReportsHomeModel.OtherReport(id: "move_out", title: "Move-out report", detail: "Not started")
        let dispute = ReportsHomeModel.OtherReport(id: "dispute", title: "Dispute packet", detail: "Ready to generate")
        m.others = [moveOut, dispute]
        let first = ReportsHomeModel.HistoryItem(id: UUID(), title: "Move-in report", date: Self.reportDay, status: .ready)
        switch state {
        case "no-report":
            m.documented = 4; m.photos = 9; m.records = 1; m.issues = 0
            m.primary = .needsProof(.rooms)
            m.primaryTitle = "Continue room proof"
            m.others = [moveOut, .init(id: "dispute", title: "Dispute packet", detail: "Needs move-in proof")]
        case "needs-record":
            m.documented = 1; m.photos = 1; m.records = 0; m.issues = 0
            m.primary = .needsProof(.record)
            m.primaryTitle = "Add a record"
        case "can-generate":
            m.primary = .canGenerate
        case "generating":
            m.primary = .generating
            m.history = [.init(id: UUID(), title: "Move-in report", date: Self.reportDay, status: .generating)]
        case "failed":
            m.primary = .failed(lastReadyAt: Self.reportDay.addingTimeInterval(-86_400 * 3))
            m.history = [.init(id: UUID(), title: "Move-in report", date: Self.reportDay, status: .failed, canRetry: true),
                         .init(id: UUID(), title: "Move-in report", date: Self.reportDay.addingTimeInterval(-86_400 * 3), status: .ready)]
        case "history":
            m.history = [first,
                         .init(id: UUID(), title: "Dispute packet", date: Self.reportDay.addingTimeInterval(-3_600), status: .generating),
                         .init(id: UUID(), title: "Move-out report", date: Self.reportDay.addingTimeInterval(-86_400), status: .failed, canRetry: true),
                         .init(id: UUID(), title: "Move-in report", date: Self.reportDay.addingTimeInterval(-86_400 * 2), status: .ready),
                         .init(id: UUID(), title: "Move-in report", date: Self.reportDay.addingTimeInterval(-86_400 * 5), status: .failed),
                         .init(id: UUID(), title: "Move-in report", date: Self.reportDay.addingTimeInterval(-86_400 * 9), status: .ready)]
            m.others = [.init(id: "move_out", title: "Move-out report", detail: "Couldn't generate · Tap to retry"),
                        .init(id: "dispute", title: "Dispute packet", detail: "Generating…", isGenerating: true)]
        case "free":
            m.history = [first]
            m.others = [.init(id: "move_out", title: "Move-out report", detail: "Re-capture rooms before you return the keys.", isProLocked: true),
                        .init(id: "dispute", title: "Dispute packet", detail: "Bundle your proof if your deposit is questioned.", isProLocked: true)]
        case "no-rental":
            m = ReportsHomeModel(rentalName: "Your rental", primary: .noRental, primaryTitle: "Go to Proof")
        default:   // ready
            m.history = [first]
        }
        return m
    }

    private func reportsScreen(_ state: String, atBottom: Bool = false) -> some View {
        ReportsHomeView(model: reportsModel(state), initialScrollAnchor: atBottom ? .bottom : nil)
            .environment(\.mmRootTabBarVisible, true)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MMProofTabBarV4(selectedTab: .constant(.exports))
            }
    }

    func testReportsReady() {
        assertSnapshot(of: host(reportsScreen("ready")), as: Self.strategy(Self.pro), named: "pro")
        assertSnapshot(of: host(reportsScreen("ready")), as: Self.strategy(Self.small), named: "small")
        assertSnapshot(of: host(reportsScreen("ready")), as: Self.strategy(Self.proAX), named: "ax3")
    }

    func testReportsNoReportYet() {
        assertSnapshot(of: host(reportsScreen("no-report")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReportsNeedsARecord() {
        assertSnapshot(of: host(reportsScreen("needs-record")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReportsMoveInCompleteNotGenerated() {
        assertSnapshot(of: host(reportsScreen("can-generate")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReportsGenerating() {
        assertSnapshot(of: host(reportsScreen("generating")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReportsFailedKeepsLastReport() {
        assertSnapshot(of: host(reportsScreen("failed")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReportsHistory() {
        assertSnapshot(of: host(reportsScreen("history")), as: Self.strategy(Self.pro), named: "pro")
        // The end of the scroll: the last row clears the floating dock.
        assertSnapshot(of: host(reportsScreen("history", atBottom: true)), as: Self.strategy(Self.pro), named: "bottom")
        assertSnapshot(of: host(reportsScreen("history", atBottom: true)), as: Self.strategy(Self.small), named: "small-bottom")
    }

    func testReportsFreePlan() {
        assertSnapshot(of: host(reportsScreen("free")), as: Self.strategy(Self.pro), named: "pro")
    }

    func testReportsNoRental() {
        assertSnapshot(of: host(reportsScreen("no-rental")), as: Self.strategy(Self.pro), named: "pro")
    }
}
