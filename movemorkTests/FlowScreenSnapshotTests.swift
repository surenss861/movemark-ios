//
//  FlowScreenSnapshotTests.swift
//  movemorkTests
//
//  @file Goldens for the flow screens on the final system (area C): Maintenance (log, issue, loading /
//        not-found), Move-out, the evidence sheets (edit proof, add photos, photo viewer, capture form), the Pro
//        paywall (loading, plans, unavailable, report pack, success, restore, toast), Edit name and the toast —
//        on the Pro phone, the small phone and AX3.
//  @domain design-system
//  @see [[MMSystem+Flows.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import RevenueCat
import SnapshotTesting
@testable import MoveMark

@MainActor
final class FlowScreenSnapshotTests: XCTestCase {
    private static let day = Date(timeIntervalSince1970: 1_761_510_540)   // Oct 26, fixed for goldens
    private static let propertyID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-000000000001")!
    private static let userID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-000000000002")!

    private var devices: [(String, ViewImageConfig)] { ScreenSnapshot.allDevices }

    // MARK: Maintenance

    private func maintenanceStore(_ log: [MaintenanceRecord]) -> PropertyStore {
        let store = PropertyStore()
        store.maintenanceLog = log
        return store
    }

    private var maintenanceLog: [MaintenanceRecord] {
        [
            MaintenanceRecord(title: "Bathroom sink leak", category: "Plumbing",
                              details: "Water pooling under the vanity; reported to the property manager by email.",
                              status: .open, createdAt: Self.day, photoCount: 3),
            MaintenanceRecord(title: "Bedroom window won't latch", category: "Structural", details: "",
                              status: .followUp, createdAt: Self.day.addingTimeInterval(-86_400 * 6), photoCount: 1),
            MaintenanceRecord(title: "Dishwasher not draining", category: "Appliance", details: "Replaced pump on Oct 2.",
                              status: .resolved, createdAt: Self.day.addingTimeInterval(-86_400 * 30), photoCount: 0),
        ]
    }

    func testMaintenanceLogPopulated() {
        assertScreen(MaintenanceLogView(path: .constant([])).environment(maintenanceStore(maintenanceLog)), devices: devices)
    }

    func testMaintenanceLogEmpty() {
        assertScreen(MaintenanceLogView(path: .constant([])).environment(maintenanceStore([])), devices: devices)
    }

    func testMaintenanceLogLoading() {
        assertScreen(MaintenanceLogView(path: .constant([]), initiallyLoading: true).environment(maintenanceStore([])))
    }

    func testMaintenanceLogError() {
        assertScreen(MaintenanceLogView(path: .constant([]), initialError: MoveMarkFlowMessage.maintenanceListSyncFailed)
            .environment(maintenanceStore(maintenanceLog)), devices: [("pro", ScreenSnapshot.pro), ("small", ScreenSnapshot.small)])
    }

    private func issue(resolved: Bool = false) -> MaintenanceIssueRow {
        MaintenanceIssueRow(
            id: UUID(uuidString: "6F1E2C3D-0000-4000-8000-0000000000AA")!, propertyId: Self.propertyID, userId: Self.userID,
            title: "Bathroom sink leak", description: "Water pooling under the vanity after every use.",
            category: "Plumbing", status: resolved ? "resolved" : "open",
            dateDiscovered: "2026-10-20T14:05:00Z", dateReported: "2026-10-21T09:30:00Z", reportMethod: "email",
            landlordResponse: resolved ? "Plumber replaced the trap on Oct 24." : nil,
            followUpDate: resolved ? "2026-10-24T16:00:00Z" : nil, updatedAt: nil
        )
    }

    func testMaintenanceIssueOpen() {
        assertScreen(MaintenanceIssueDetailView(issue: issue()), devices: devices)
    }

    func testMaintenanceIssueResolved() {
        assertScreen(MaintenanceIssueDetailView(issue: issue(resolved: true)))
    }

    func testMaintenanceIssueError() {
        assertScreen(MaintenanceIssueDetailView(issue: issue(), initialError: "Couldn’t save follow-up. Check your connection and try again."))
    }

    func testMaintenanceIssueNotFound() {
        assertScreen(MaintenanceIssueDetailContainerView(issueID: UUID(), initialError: MoveMarkFlowMessage.maintenanceIssueNotFound),
                     devices: devices)
    }

    func testMaintenanceIssueLoading() {
        // A real property makes the container wait on the network lookup, so the loading state holds.
        let store = PropertyStore()
        store.currentProperty = property(rooms: [])
        assertScreen(MaintenanceIssueDetailContainerView(issueID: UUID()).environment(store))
    }

    // MARK: Move-out

    private func property(rooms: [RoomRecord]) -> PropertyRecord {
        PropertyRecord(id: Self.propertyID, title: "88 Harbour St", addressLine1: "88 Harbour St", moveInDate: Self.day,
                       leaseEndDate: Self.day, rooms: rooms)
    }

    private func entry(_ title: String, stage: EvidenceRecord.Stage, condition: RoomRecord.ConditionRating, photos: Int) -> EvidenceRecord {
        EvidenceRecord(title: title, notes: "", issueTags: [], condition: condition, createdAt: Self.day, photoCount: photos, stage: stage)
    }

    private var moveOutRooms: [RoomRecord] {
        [
            RoomRecord(name: "Living Room", evidence: [entry("Walls", stage: .moveIn, condition: .good, photos: 4)],
                       moveOutEvidence: [entry("Walls", stage: .moveOut, condition: .good, photos: 3)]),
            RoomRecord(name: "Kitchen", evidence: [entry("Counters", stage: .moveIn, condition: .good, photos: 2)],
                       moveOutEvidence: [entry("Counters", stage: .moveOut, condition: .fair, photos: 2)]),
            RoomRecord(name: "Bedroom", evidence: [entry("Floor", stage: .moveIn, condition: .fair, photos: 3)]),
        ]
    }

    private var checklist: MoveOutChecklistRow {
        MoveOutChecklistRow(id: UUID(), propertyId: Self.propertyID, userId: Self.userID, cabinetsClear: true,
                            appliancesClean: true, keysReturned: false, utilitiesCancelled: false,
                            cleaningReceiptUploaded: false, forwardingAddressNoted: true)
    }

    private func moveOutStore(rooms: [RoomRecord]?) -> PropertyStore {
        let store = PropertyStore()
        if let rooms { store.currentProperty = property(rooms: rooms) }
        return store
    }

    func testMoveOutPopulated() {
        assertScreen(MoveOutFoundationView(path: .constant([]), initialChecklist: checklist).environment(moveOutStore(rooms: moveOutRooms)),
                     devices: devices)
    }

    func testMoveOutEmpty() {
        assertScreen(MoveOutFoundationView(path: .constant([])).environment(moveOutStore(rooms: [])), devices: devices)
    }

    func testMoveOutExporting() {
        assertScreen(MoveOutFoundationView(path: .constant([]), initiallyExporting: true)
            .environment(moveOutStore(rooms: Array(moveOutRooms.prefix(1)))))
    }

    func testMoveOutQueued() {
        assertScreen(MoveOutFoundationView(path: .constant([]),
                                           initialQueuedNotice: "Report queued — it will appear in Reports when ready")
            .environment(moveOutStore(rooms: Array(moveOutRooms.prefix(1)))))
    }

    func testMoveOutError() {
        assertScreen(MoveOutFoundationView(path: .constant([]), initialChecklist: checklist,
                                           initialError: "Couldn't queue move-out report. Try again.")
            .environment(moveOutStore(rooms: moveOutRooms)))
    }

    // MARK: Evidence surfaces (dark)

    private var savedEntry: EvidenceRecord {
        EvidenceRecord(title: "North wall", notes: "Two scratches beside the window.", issueTags: ["Scratch", "Chipped paint"],
                       condition: .fair, createdAt: Self.day, photoCount: 5, stage: .moveIn)
    }

    func testEditEvidenceSheet() {
        assertScreen(EditEvidenceSheet(evidence: savedEntry, roomName: "Living Room", onSave: { _, _, _, _ in nil }, onDismiss: {}),
                     devices: devices, inNavigation: false)
    }

    func testAppendPhotosSheet() {
        assertScreen(AppendPhotosSheet(entry: savedEntry, onAdd: { _ in ([], nil) }, onDismiss: {}),
                     devices: devices, inNavigation: false)
    }

    func testRoomPhotoViewer() {
        let photos = (0..<3).map { EvidencePhoto(id: UUID(uuidString: "6F1E2C3D-0000-4000-8000-00000000010\($0)")!, filePath: "fixture/\($0).jpg") }
        assertScreen(RoomPhotoViewer(photos: photos, startID: photos[1].id, resolvePhotoURL: { _ in nil }, onClose: {}),
                     devices: [("pro", ScreenSnapshot.pro), ("ax3", ScreenSnapshot.proAX)], inNavigation: false)
    }

    private func captureForm(error: String? = nil, success: String? = nil) -> some View {
        ScrollView {
            EvidenceCaptureForm(
                title: .constant("North wall paint wear"), notes: .constant(""), selectedTags: .constant(["Scratch"]),
                selectedCondition: .constant(.fair), selectedItems: .constant([]), loadedImages: [], isUploading: false,
                errorMessage: error, successMessage: success, moveOutMode: false,
                fixedIssueTags: ["Scratch", "Stain", "Water damage", "Chipped paint", "Cracked tile", "Appliance damage"]
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(MMInk.evidence)
        .environment(\.colorScheme, .dark)
    }

    func testEvidenceCaptureForm() {
        assertScreen(captureForm(), devices: devices, inNavigation: false)
    }

    func testEvidenceCaptureFormStates() {
        assertScreen(captureForm(error: "2 photos didn’t save. Your entry is kept — try again.", success: "Proof saved on this room."),
                     inNavigation: false)
    }

    // MARK: Paywall

    private func package(_ id: String, _ type: PackageType, price: Decimal, label: String, unit: SubscriptionPeriod.Unit?) -> Package {
        let product = TestStoreProduct(
            localizedTitle: "", price: price, localizedPriceString: label, productIdentifier: id,
            productType: unit == nil ? .nonConsumable : .autoRenewableSubscription, localizedDescription: "",
            subscriptionPeriod: unit.map { SubscriptionPeriod(value: 1, unit: $0) }
        )
        return Package(identifier: id, packageType: type, storeProduct: product.toStoreProduct(), offeringIdentifier: "default",
                       webCheckoutUrl: nil)
    }

    private func subscriptions(plans: Bool, reportPack: Bool = false) -> SubscriptionManager {
        let manager = SubscriptionManager()
        guard plans else { return manager }
        var packages = [
            package("monthly_subscription", .monthly, price: 7.99, label: "$7.99", unit: .month),
            package("yearly_subscription", .annual, price: 49.99, label: "$49.99", unit: .year),
        ]
        if reportPack { packages.append(package("report_pack", .lifetime, price: 9.99, label: "$9.99", unit: nil)) }
        manager.currentOffering = Offering(identifier: "default", serverDescription: "Default", availablePackages: packages,
                                           webCheckoutUrl: nil)
        return manager
    }

    private func paywall(_ reason: PaywallReason = .moveOutExport, plans: Bool = true, reportPack: Bool = false,
                         fetched: Bool = true, success: Bool = false, restore: String? = nil, error: String? = nil,
                         toast: MMProofToastMessage? = nil) -> some View {
        ProPaywallView(reason: reason, onClose: {}, initialOfferingsFetchCompleted: fetched, showPurchaseSuccess: success,
                       restoreOutcomeMessage: restore, localErrorMessage: error, toast: toast)
            .environment(subscriptions(plans: plans, reportPack: reportPack))
    }

    func testPaywallPlans() {
        assertScreen(paywall(), devices: devices, inNavigation: false)
    }

    func testPaywallLoading() {
        assertScreen(paywall(plans: false, fetched: false), inNavigation: false)
    }

    func testPaywallUnavailable() {
        assertScreen(paywall(plans: false), devices: [("pro", ScreenSnapshot.pro), ("small", ScreenSnapshot.small)], inNavigation: false)
    }

    func testPaywallReportPack() {
        assertScreen(paywall(.reportPack, reportPack: true), inNavigation: false)
    }

    func testPaywallPurchaseSuccess() {
        assertScreen(paywall(success: true), inNavigation: false)
    }

    func testPaywallRestoreResultAndError() {
        assertScreen(paywall(restore: "No active subscription or Report Pack was found for this Apple ID.",
                             error: "Purchase didn’t go through. Try again."), inNavigation: false)
    }

    func testPaywallToast() {
        assertScreen(paywall(plans: false, toast: .plansDidNotLoad()), inNavigation: false)
    }

    // MARK: Account / toast

    func testEditNameSheet() {
        assertScreen(EditNameSheet(currentName: "Suren Kumar", onSave: { _ in }), devices: devices, inNavigation: false)
    }

    func testProofToastSuccess() {
        let toasts = VStack(spacing: 12) {
            MMProofToast(message: .proofSaved())
            MMProofToast(message: .reportQueued())
            MMProofToast(message: .plansDidNotLoad())
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        assertScreen(toasts.background(MoveMarkTheme.Colors.appBackground).environment(\.colorScheme, .dark),
                     inNavigation: false, testName: "testProofToastSuccessDark")
    }
}
