//
//  MMRoomProgressCard.swift
//  movemork
//
//  Room proof progress — next action for renters, not a metrics dashboard.
//

import SwiftUI

struct MMRoomProgressCard: View {
    let headline: String
    let nextLine: String
    let progress: Double
    var progressLabel: String? = nil
    let primaryTitle: String
    let onPrimary: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double { min(1, max(0, progress)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Room proof")
                    .font(MoveMarkTheme.Typography.captionEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)

                Text(headline)
                    .font(MoveMarkTheme.Typography.button)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .mmRowStatusTransition(value: headline)

                Text(nextLine)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .mmRowStatusTransition(value: nextLine)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.85))
                        .frame(height: 4)
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary.opacity(0.88))
                        .frame(width: max(4, geo.size.width * clampedProgress), height: 4)
                        .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clampedProgress)
                }
            }
            .frame(height: 4)

            if let progressLabel, !progressLabel.isEmpty {
                Text(progressLabel)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }

            MMButton(
                title: primaryTitle,
                action: {
                    MMHaptics.soft()
                    onPrimary()
                },
                kind: .primary,
                size: .standard
            )
        }
        .padding(16)
        .mmProofCardSurface(.neutral, cornerRadius: 18)
    }
}
