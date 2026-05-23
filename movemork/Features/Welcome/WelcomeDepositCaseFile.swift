//
//  WelcomeDepositCaseFile.swift
//  movemork
//

import SwiftUI

struct WelcomeDepositCaseFile: View {
    let maxWidth: CGFloat
    let heroHeight: CGFloat
    var cardVisible: Bool = true
    var tagsVisible: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cornerRadius: CGFloat = 24
    private let metadataAndReceiptHeight: CGFloat = 118

    private var photoHeight: CGFloat {
        max(heroHeight - metadataAndReceiptHeight, 140)
    }

    private let issueTags: [ProofIssueTag] = [
        ProofIssueTag(id: "prior", label: "Already there", priorDamage: true, leadingInset: 4),
        ProofIssueTag(id: "paint", label: "Chipped paint", leadingInset: 22),
        ProofIssueTag(id: "stain", label: "Water stain", leadingInset: 36)
    ]

    var body: some View {
        ProofCaseCard(
            style: .marketing,
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
                    roomName: "Kitchen",
                    phaseLabel: "Move-in proof",
                    phaseBadge: "Before move-in",
                    issueTags: issueTags,
                    tagsVisible: tagsVisible,
                    showScanCorners: true
                )
                .frame(height: photoHeight)
            },
            footer: {
                ProofReceiptStrip(
                    model: {
                        var m = ProofReceiptStripModel()
                        m.detailTitle = "Kitchen"
                        m.detailSubtitle = "12 photos · 3 issues"
                        m.savedTitle = "Saved to your vault"
                        m.timestampLabel = "Move-in · Apr 14 · 5:42 PM"
                        m.statusBadge = "Ready"
                        m.statusTone = .success
                        return m
                    }(),
                    layout: .caseFile
                )
            }
        )
        .frame(width: maxWidth, height: heroHeight)
        .opacity(cardVisible ? 1 : 0)
        .offset(y: cardVisible ? 0 : 14)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.48), value: cardVisible)
    }
}

struct WelcomeEvidenceDeskRuledPaper: View {
    var body: some View { EmptyView() }
}
