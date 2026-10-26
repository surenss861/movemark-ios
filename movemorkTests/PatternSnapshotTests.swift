//
//  PatternSnapshotTests.swift
//  movemorkTests
//
//  @file The design-system contract for the evidence patterns (MMSystem+Patterns): Proof Slip, Evidence Tile,
//        Case Card, Timeline Row, Progress Strip, Comparison Pair. Every screen that uses them inherits these.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

@MainActor
final class PatternSnapshotTests: XCTestCase {

    private static func photo(_ name: String) -> UIImage? {
        guard let url = Bundle(for: PatternSnapshotTests.self).url(forResource: name, withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static func evidence(_ name: String, _ size: CGSize) -> some View {
        MMEvidenceImage(path: "fixture/\(name).jpg", resolve: { _ in nil }, size: size, placeholder: MMInk.field)
    }

    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                MMProofSlip(kind: "Move-in record", subject: "Kitchen", timestamp: "Oct 24 · 3:18 PM",
                            lines: ["12 photos", "2 issues documented"], reference: "MM-28412")

                HStack(alignment: .top, spacing: 10) {
                    MMEvidenceTile(caption: "Living Room", meta: "Today · 4 photos", size: CGSize(width: 110, height: 110)) {
                        Self.evidence("snap-living", CGSize(width: 110, height: 110))
                    }
                    MMEvidenceTile(caption: "Kitchen", meta: "Oct 24 · 2 photos", size: CGSize(width: 110, height: 110)) {
                        Self.evidence("snap-kitchen", CGSize(width: 110, height: 110))
                    }
                }

                MMCaseCard(eyebrow: "Maintenance case", title: "Water leak under sink", status: ("Open", .open),
                           facts: [.init(label: "Reported", value: "Oct 24 · 9:42 PM"), .init(label: "Evidence", value: "4 photos"),
                                   .init(label: "Room", value: "Kitchen"), .init(label: "Landlord", value: "Contacted Oct 25")])

                MMPanel {
                    MMTimelineRow(date: "Oct 24", title: "Issue recorded", detail: "4 photos, under the sink", isFirst: true)
                    MMTimelineRow(date: "Oct 25", title: "Landlord contacted")
                    MMTimelineRow(date: "Oct 28", title: "Repair completed", isLast: true, isPending: true)
                }

                MMProgressStrip(label: "Move-out proof", done: 3, total: 8)

                MMComparisonPair(title: "Living Room", change: .changed,
                                 beforeNote: "No damage", beforeDate: "Oct 24", afterNote: "Wall scuff noted", afterDate: "Apr 30",
                                 before: { Self.evidence("snap-living", CGSize(width: 180, height: 150)) },
                                 after: { Self.evidence("snap-hero", CGSize(width: 180, height: 150)) })
                MMComparisonPair(title: "Bathroom", change: .missingAfter, beforeNote: "Grout intact", beforeDate: "Oct 24",
                                 before: { Self.evidence("snap-bedroom", CGSize(width: 180, height: 150)) },
                                 after: { MMMissingPhotoFrame() })
            }
            .padding(20)
        }
        .background(MMInk.sheet)
        .environment(\.colorScheme, .light)
        .environment(\.mmEvidenceImageOverride, { path in
            Self.photo((path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? path)
        })
    }

    func testPatternsGallery() {
        let tall = ViewImageConfig(safeArea: .zero, size: CGSize(width: 402, height: 1900),
                                   traits: UITraitCollection(traitsFrom: [.init(displayScale: 3), .init(userInterfaceStyle: .light)]))
        assertSnapshot(of: UIHostingController(rootView: gallery), as: ScreenSnapshot.strategy(tall), named: "tall")
        let tallAX = ViewImageConfig(safeArea: .zero, size: CGSize(width: 402, height: 3000),
                                     traits: UITraitCollection(traitsFrom: [tall.traits, .init(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)]))
        assertSnapshot(of: UIHostingController(rootView: gallery), as: ScreenSnapshot.strategy(tallAX), named: "ax3")
    }
}
