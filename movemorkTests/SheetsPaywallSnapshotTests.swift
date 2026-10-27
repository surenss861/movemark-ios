//
//  SheetsPaywallSnapshotTests.swift
//  movemorkTests
//
//  @file Goldens for the round-2 sheets and the paywall: Edit evidence (tags + notes, plain, many photos),
//        Add photos (empty, 3 pending), the Pro paywall (plans, loading, unavailable, purchase success, Report
//        Pack, restore result + error, toast) and Edit name (empty, filled, error) — Pro phone, small phone, AX3.
//  @domain design-system
//  @see [[MMSystem+Sheets.swift]] · [[ProPaywallView.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import RevenueCat
import SnapshotTesting
@testable import MoveMark

@MainActor
final class SheetsPaywallSnapshotTests: XCTestCase {
    private static let day = Date(timeIntervalSince1970: 1_761_510_540)   // Oct 26, fixed for goldens
    private var devices: [(String, ViewImageConfig)] { ScreenSnapshot.allDevices }

    // MARK: Fixtures

    private static func photo(_ name: String) -> UIImage? {
        guard let url = Bundle(for: SheetsPaywallSnapshotTests.self).url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static let fixtureNames = ["snap-living", "snap-hero", "snap-kitchen", "snap-bedroom"]

    private static func photos(_ count: Int) -> [EvidencePhoto] {
        (0..<count).map { EvidencePhoto(id: UUID(), filePath: "fixture/\(fixtureNames[$0 % fixtureNames.count]).jpg") }
    }

    /// Resolves `fixture/<name>.jpg` paths to the bundled photos, as the app would after a signed-URL load.
    private func withPhotos<V: View>(_ view: V) -> some View {
        view.environment(\.mmEvidenceImageOverride, { path in
            Self.photo((path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path)
        })
    }

    private func entry(title: String = "North wall", notes: String = "", tags: [String] = [],
                       condition: RoomRecord.ConditionRating = .good, photoCount: Int, loaded: Int) -> EvidenceRecord {
        EvidenceRecord(title: title, notes: notes, issueTags: tags, condition: condition, createdAt: Self.day,
                       photoCount: photoCount, photos: Self.photos(loaded), stage: .moveIn)
    }

    // MARK: Edit evidence

    private func editEvidence(_ evidence: EvidenceRecord) -> some View {
        withPhotos(EditEvidenceSheet(evidence: evidence, roomName: "Living Room", onSave: { _, _, _, _ in nil }, onDismiss: {}))
    }

    func testEditEvidenceTagsAndNotes() {
        let record = entry(notes: "Two scratches beside the window.", tags: ["Scratch", "Chipped paint"], condition: .fair,
                           photoCount: 3, loaded: 3)
        assertScreen(editEvidence(record), devices: devices, inNavigation: false)
    }

    func testEditEvidencePlain() {
        assertScreen(editEvidence(entry(title: "Living Room", photoCount: 1, loaded: 1)), devices: devices, inNavigation: false)
    }

    func testEditEvidenceManyPhotos() {
        let record = entry(notes: "Wall and floor by the window.", tags: ["Stain"], condition: .good, photoCount: 9, loaded: 5)
        assertScreen(editEvidence(record), devices: devices, inNavigation: false)
    }

    // MARK: Add photos

    private func appendPhotos(_ images: [UIImage] = []) -> some View {
        AppendPhotosSheet(entry: entry(photoCount: 4, loaded: 4), onAdd: { _ in ([], nil) }, onDismiss: {}, previewImages: images)
    }

    func testAddPhotosEmpty() {
        assertScreen(appendPhotos(), devices: devices, inNavigation: false)
    }

    func testAddPhotosThreePending() {
        let images = ["snap-kitchen", "snap-bedroom", "snap-hero"].compactMap(Self.photo)
        XCTAssertEqual(images.count, 3)
        assertScreen(appendPhotos(images), devices: devices, inNavigation: false)
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
                         fetched: Bool = true, success: Bool = false, successReportPack: Bool = false,
                         restore: String? = nil, error: String? = nil, toast: MMProofToastMessage? = nil) -> some View {
        ProPaywallView(reason: reason, onClose: {}, initialOfferingsFetchCompleted: fetched, showPurchaseSuccess: success,
                       purchaseSuccessWasReportPack: successReportPack, restoreOutcomeMessage: restore,
                       localErrorMessage: error, toast: toast)
            .environment(subscriptions(plans: plans, reportPack: reportPack))
    }

    func testPaywallPlans() {
        assertScreen(paywall(), devices: devices, inNavigation: false)
    }

    func testPaywallLoading() {
        assertScreen(paywall(plans: false, fetched: false), devices: devices, inNavigation: false)
    }

    func testPaywallUnavailable() {
        assertScreen(paywall(plans: false), devices: devices, inNavigation: false)
    }

    func testPaywallPurchaseSuccess() {
        assertScreen(paywall(success: true), devices: devices, inNavigation: false)
    }

    func testPaywallReportPack() {
        assertScreen(paywall(.reportPack, reportPack: true), devices: devices, inNavigation: false)
    }

    func testPaywallReportPackSuccess() {
        assertScreen(paywall(.reportPack, reportPack: true, success: true, successReportPack: true), inNavigation: false)
    }

    func testPaywallRestoreResultAndError() {
        assertScreen(paywall(restore: "No active subscription or Report Pack was found for this Apple ID.",
                             error: "Purchase didn’t go through. Try again."), devices: devices, inNavigation: false)
    }

    func testPaywallToast() {
        assertScreen(paywall(plans: false, toast: .plansDidNotLoad()), inNavigation: false)
    }

    // MARK: Edit name

    func testEditNameEmpty() {
        assertScreen(EditNameSheet(currentName: "", onSave: { _ in }), devices: devices, inNavigation: false)
    }

    func testEditNameFilled() {
        assertScreen(EditNameSheet(currentName: "Suren Kumar", onSave: { _ in }), devices: devices, inNavigation: false)
    }

    func testEditNameError() {
        assertScreen(EditNameSheet(currentName: "Suren Kumar", onSave: { _ in }, draftName: "Suren S. Kumar",
                                   initialError: "Couldn’t update your name. Check your connection and try again."),
                     devices: devices, inNavigation: false)
    }
}
