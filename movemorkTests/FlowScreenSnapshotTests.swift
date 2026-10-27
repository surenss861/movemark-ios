//
//  FlowScreenSnapshotTests.swift
//  movemorkTests
//
//  @file Goldens for the flow screens on the final system (area C): Move-out, the capture form and the toast —
//        on the Pro phone, the small phone and AX3. Edit evidence, Add photos, the paywall and Edit name moved to
//        SheetsPaywallSnapshotTests (round 2).
//  @domain design-system
//  @see [[MMSystem+Flows.swift]] — Maintenance and the evidence viewer: MaintenanceCaseSnapshotTests
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class FlowScreenSnapshotTests: XCTestCase {
    private static let day = Date(timeIntervalSince1970: 1_761_510_540)   // Oct 26, fixed for goldens
    private static let propertyID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-000000000001")!
    private static let userID = UUID(uuidString: "6F1E2C3D-0000-4000-8000-000000000002")!

    private var devices: [(String, ViewImageConfig)] { ScreenSnapshot.allDevices }

    // MARK: Evidence surfaces (dark)

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

    // MARK: Toast

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
