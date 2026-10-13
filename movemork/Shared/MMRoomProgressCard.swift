//
//  MMRoomProgressCard.swift
//  movemork
//
//  Proof Sprint coverage. The active room below this card is the star; this states the count.
//

import SwiftUI

struct MMRoomProgressCard: View {
    let headline: String
    let nextLine: String
    let progress: Double
    var progressLabel: String? = nil
    let primaryTitle: String
    let onPrimary: () -> Void
    var documentedCount: Int? = nil
    var totalCount: Int? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double { min(1, max(0, progress)) }

    private var showsFigure: Bool {
        guard let totalCount, totalCount > 0, documentedCount != nil else { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsFigure, let documentedCount, let totalCount {
                HStack(alignment: .center, spacing: 12) {
                    MMCoverageFigure(documented: documentedCount, total: totalCount)
                    Spacer(minLength: 8)
                    ProgressRingView(progress: clampedProgress, size: 58, lineWidth: 3)
                        .accessibilityHidden(true)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headline)
                        .font(MoveMarkTheme.Typography.cardTitleCompact)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .mmRowStatusTransition(value: headline)

                    coverageBar
                }
            }

            Text(nextLine)
                .font(MoveMarkTheme.Typography.metadata)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .mmRowStatusTransition(value: nextLine)

            if let progressLabel, !progressLabel.isEmpty {
                Text(progressLabel)
                    .font(MoveMarkTheme.Typography.monoMeta)
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
        .mmCaseFilePlate(emphasis: false)
    }

    private var coverageBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 3)
                Capsule()
                    .fill(MoveMarkTheme.Colors.primary.opacity(0.9))
                    .frame(width: max(3, geo.size.width * clampedProgress), height: 3)
                    .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clampedProgress)
            }
        }
        .frame(height: 3)
    }
}
