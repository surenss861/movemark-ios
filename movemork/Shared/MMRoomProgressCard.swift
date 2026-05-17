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
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Move-in proof")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)

                Text(headline)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(nextLine)
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.9))
                            .frame(height: 5)
                        Capsule()
                            .fill(MoveMarkTheme.Colors.primary.opacity(0.88))
                            .frame(width: max(6, geo.size.width * clampedProgress), height: 5)
                            .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clampedProgress)
                    }
                }
                .frame(height: 5)

                if let progressLabel, !progressLabel.isEmpty {
                    Text(progressLabel)
                        .font(MoveMarkTheme.Typography.caption)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
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
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.5), lineWidth: 0.75)
        )
    }
}
