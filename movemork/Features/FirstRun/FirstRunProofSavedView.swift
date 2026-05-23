//
//  FirstRunProofSavedView.swift
//  movemork
//

import SwiftUI

struct FirstRunProofSavedView: View {
    let summary: FirstRunSavedSummary
    let onContinueNextRoom: () -> Void
    let onViewProofVault: () -> Void

    private var formattedTime: String {
        summary.savedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var metaLine: String {
        let photos = summary.photoCount == 1 ? "1 photo" : "\(summary.photoCount) photos"
        let issues = summary.issueCount == 1 ? "1 issue tagged" : "\(summary.issueCount) issues tagged"
        return "\(photos) · \(issues) · \(formattedTime)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                MMRenterHeader(
                    title: "Saved to your vault",
                    subtitle: "This room is on record before you settle in.",
                    eyebrow: "Move-in proof"
                )

                MMProofReceiptCard(
                    statusLabel: "Saved proof",
                    title: summary.roomName,
                    metaLine: metaLine,
                    photoCount: summary.photoCount,
                    issueCount: summary.issueCount
                )

                VStack(spacing: 12) {
                    MMButton(
                        title: "Continue next room",
                        action: onContinueNextRoom,
                        kind: .primary,
                        size: .auth
                    )

                    MMButton(
                        title: "View proof vault",
                        action: onViewProofVault,
                        kind: .secondary,
                        size: .standard
                    )
                }
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .mmProofShellBackground(heroFocus: false, ctaBloom: true)
    }
}
