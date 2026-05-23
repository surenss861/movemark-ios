//
//  WelcomeDepositCaseFile.swift
//  movemork
//

import SwiftUI

struct WelcomeDepositCaseFile: View {
    let maxWidth: CGFloat
    var cardVisible: Bool = true
    var tagsVisible: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cornerRadius: CGFloat = 28
    private let embeddedPhotoHeight: CGFloat = 148

    private let issueTags: [ProofIssueTag] = [
        ProofIssueTag(id: "prior", label: "Already there", priorDamage: true, leadingInset: 4),
        ProofIssueTag(id: "paint", label: "Chipped paint", leadingInset: 22),
        ProofIssueTag(id: "stain", label: "Water stain", leadingInset: 36)
    ]

    var body: some View {
        ProofCaseCard(
            style: .standard,
            cornerRadius: cornerRadius,
            header: ProofCaseHeader(
                eyebrow: "Move-in proof",
                statusLabel: "Report ready",
                statusTone: .success,
                accentRail: .saved
            ),
            content: {
                ProofPhotoPane(
                    size: .large,
                    imageName: "welcome-kitchen-main",
                    issueTags: issueTags,
                    tagsVisible: tagsVisible,
                    overlayStyle: .tagsOnly,
                    showScanCorners: true,
                    embeddedInCaseFile: true
                )
                .frame(height: embeddedPhotoHeight)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                ProofCaseDivider()
                ProofCaseDetailSection(
                    title: "Kitchen",
                    subtitle: "12 photos · 3 issues"
                )
                ProofCaseDivider()
                ProofCaseReceiptRow(
                    savedTitle: "Saved to your vault",
                    timestampLabel: "Move-in · Apr 14 · 5:42 PM",
                    statusBadge: "Ready",
                    statusTone: .success
                )
            }
        )
        .frame(maxWidth: maxWidth)
        .opacity(cardVisible ? 1 : 0)
        .offset(y: cardVisible ? 0 : 14)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.48), value: cardVisible)
    }
}

struct WelcomeEvidenceDeskRuledPaper: View {
    var body: some View { EmptyView() }
}
