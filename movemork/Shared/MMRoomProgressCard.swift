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
                Text(headline)
                    .font(MoveMarkTheme.Typography.cardTitleCompact)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .mmRowStatusTransition(value: headline)

                Text(nextLine)
                    .font(MoveMarkTheme.Typography.metadata)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .mmRowStatusTransition(value: nextLine)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary.opacity(0.88))
                        .frame(width: max(6, geo.size.width * clampedProgress), height: 6)
                        .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clampedProgress)
                }
            }
            .frame(height: 6)

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
                size: .inline
            )
        }
        .padding(MoveMarkTheme.Spacing.panelPadding)
        .background(
            RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.hero, style: .continuous)
                .fill(MoveMarkTheme.Surface.raised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.hero, style: .continuous)
                .stroke(MoveMarkTheme.Stroke.interactive, lineWidth: 1)
        )
    }
}
