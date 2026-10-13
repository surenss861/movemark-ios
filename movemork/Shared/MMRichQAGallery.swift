//
//  MMRichQAGallery.swift
//  movemork
//
//  Debug-only runtime check for the three rich screens. Launch with -MMRichQA <case>.
//  Not a product screen.
//

#if DEBUG
import SwiftUI

struct MMRichQAGallery: View {
    let screen: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                screenBody
                Color.clear.frame(height: MoveMarkTheme.Spacing.scrollTailRootTabChrome)
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .mmProofShellBackground(heroFocus: true, ctaBloom: false)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var screenBody: some View {
        switch screen {
        case "vault-0":
            vault(documented: 0, total: 10, photos: 0, records: 0, issues: 0, address: "123 Main St", next: "Kitchen")
        case "vault-1":
            vault(documented: 1, total: 10, photos: 4, records: 1, issues: 0, address: "123 Main St", next: "Living Room", lastProof: "Sep 28 · 6:34 PM")
        case "vault-9":
            vault(documented: 9, total: 10, photos: 24, records: 3, issues: 2, address: "123 Main St", next: "Primary Bedroom", lastProof: "Sep 28 · 6:34 PM")
        case "vault-10":
            vault(documented: 10, total: 10, photos: 31, records: 3, issues: 0, address: "123 Main St", next: nil, lastProof: "Oct 2 · 9:12 AM", primary: "Review your rooms")
        case "vault-long":
            vault(documented: 9, total: 10, photos: 24, records: 3, issues: 2, address: "1234 Westmoreland Avenue Northwest, Apartment 14B", next: "Balcony/Patio", lastProof: "Sep 28 · 6:34 PM")
        case "sprint-first":
            sprint(doneThrough: 0, current: "Kitchen")
        case "sprint-middle":
            sprint(doneThrough: 2, current: "Primary Bedroom")
        case "sprint-final":
            sprint(doneThrough: 9, current: "Office")
        case "reports-empty":
            reports(state: .notReady, title: "Document a room to make your first report.", chips: [])
        case "reports-generating":
            reports(state: .processing, title: "Generating your record.", chips: ["9 rooms", "24 photos"])
        case "reports-ready":
            reports(state: .ready, title: "Your move-in record is ready.", chips: ["9 rooms", "24 photos", "2 issues"], generated: "Generated Sep 28 · 6:34 PM", recordId: "MM-RP-4C82", history: true)
        case "reports-failed":
            reports(state: .failed, title: "The report didn’t finish.", chips: ["9 rooms", "24 photos"])
        case "reports-pro":
            reportsPro
        default:
            Text(screen)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
        }
    }

    private func vault(
        documented: Int,
        total: Int,
        photos: Int,
        records: Int,
        issues: Int,
        address: String,
        next: String?,
        lastProof: String? = nil,
        primary: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            MMProofSectionHeader(title: "Your proof", subtitle: "Document now. Prove it later.")
            MMVaultProofHeroCard(
                propertyName: address,
                location: "Toronto, ON",
                coverageLine: "\(documented) of \(total) rooms documented",
                nextRoomName: next,
                progress: total == 0 ? 0 : Double(documented) / Double(total),
                primaryTitle: primary ?? (next.map { "Capture \($0)" } ?? "Review your rooms"),
                onPrimary: {},
                documentedCount: documented,
                totalRooms: total,
                photoCount: photos,
                recordCount: records,
                issueCount: issues,
                lastProofLine: lastProof
            )
        }
    }

    private let sprintRooms = [
        "Kitchen", "Living Room", "Primary Bedroom", "Balcony/Patio", "Bathroom",
        "Hallway", "Laundry", "Storage", "Bedroom 2", "Office",
    ]

    private func sprint(doneThrough: Int, current: String) -> some View {
        let documented = sprintRooms.filter { room in
            guard let index = sprintRooms.firstIndex(of: room) else { return false }
            return index < doneThrough
        }.count
        return VStack(alignment: .leading, spacing: 18) {
            MMRoomProgressCard(
                headline: "\(documented) of \(sprintRooms.count) rooms documented",
                nextLine: "Next: \(current)",
                progress: Double(documented) / Double(sprintRooms.count),
                primaryTitle: "Capture \(current)",
                onPrimary: {},
                documentedCount: documented,
                totalCount: sprintRooms.count
            )
            ForEach(Array(sprintRooms.enumerated()), id: \.offset) { index, name in
                let done = index < doneThrough
                let isNext = name == current
                MMRoomProofRow(
                    index: index + 1,
                    roomName: name,
                    status: done
                        ? .readyToReview(photoCount: 4, issueCount: name == "Kitchen" ? 1 : 0)
                        : (isNext ? .nextUp : .needsPhotos),
                    showsNextBadge: isNext,
                    onTap: {}
                )
            }
        }
    }

    private func reports(
        state: MMReportPreviewHero.State,
        title: String,
        chips: [String],
        generated: String? = nil,
        recordId: String? = nil,
        history: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            MMProofSectionHeader(title: "Your reports", subtitle: "Shareable records built from your saved proof.")
            MMReportPreviewHero(
                state: state,
                metricsLine: chips.isEmpty ? nil : chips.joined(separator: " · "),
                headline: title,
                footnote: title,
                proofChips: chips,
                primaryTitle: state == .ready ? "View" : (state == .failed ? "Try again" : "Generate record"),
                generatedLine: generated,
                recordId: recordId,
                onPrimary: {}
            )
            if history {
                historyList
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EXPORT HISTORY")
                .font(MoveMarkTheme.Typography.kicker)
                .tracking(1)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                ExportHistoryRow(title: "Move-in report", dateLine: "Sep 28 · 6:34 PM", recordId: "MM-RP-4C82", statusLabel: "Ready", statusTone: .success, canShare: true, onShare: {})
                ExportHistoryRow(title: "Move-in report", dateLine: "Sep 12 · 8:02 PM", recordId: "MM-RP-19AA", statusLabel: "Ready", statusTone: .success, canShare: true, onShare: {})
                ExportHistoryRow(title: "Move-out report", dateLine: "Oct 2 · 9:12 AM", recordId: "MM-RP-77B1", statusLabel: "Failed", statusTone: .danger, canRetry: true, onShare: {}, onRetry: {})
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(MoveMarkTheme.Surface.raised))
        }
    }

    private var reportsPro: some View {
        VStack(alignment: .leading, spacing: 16) {
            MMProofSectionHeader(title: "Your reports", subtitle: "Shareable records built from your saved proof.")
            MMReportPreviewHero(
                state: .ready,
                metricsLine: "9 rooms · 24 photos",
                headline: "Your move-in record is ready.",
                primaryTitle: "View",
                generatedLine: "Generated Sep 28 · 6:34 PM",
                recordId: "MM-RP-4C82",
                onPrimary: {}
            )
            MMReportExportSection(
                sectionTitle: "Move-out report",
                sectionSubtitle: "Re-capture the same rooms when you leave.",
                statusLabel: "Ready to share",
                statusTone: .success,
                primaryTitle: "Unlock with MoveMark Pro",
                isProLocked: true,
                onPrimary: {}
            )
        }
    }
}
#endif
