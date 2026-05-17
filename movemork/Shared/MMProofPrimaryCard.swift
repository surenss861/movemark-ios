//
//  MMProofPrimaryCard.swift
//  movemork
//
//  Primary vault / report readiness card — one clear next action.
//

import SwiftUI

struct MMProofPrimaryCard: View {
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    var leadingSystemImage: String? = nil
    let headline: String
    let nextLine: String
    var progress: Double? = nil
    var statusPill: String? = nil
    var statusPillTone: MMPill.Tone = .warning
    var bodyText: String? = nil
    let primaryTitle: String
    let onPrimary: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double {
        guard let progress else { return 0 }
        return min(1, max(0, progress))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                if let leadingSystemImage {
                    Image(systemName: leadingSystemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))
                        .frame(width: 44, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.85))
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let eyebrow, !eyebrow.isEmpty {
                        Text(eyebrow)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    }

                    Text(title)
                        .font(MoveMarkTheme.Typography.cardTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(MoveMarkTheme.Typography.subheadline)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let statusPill, !statusPill.isEmpty {
                        MMPill(text: statusPill, tone: statusPillTone)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text(nextLine)
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                if let bodyText, !bodyText.isEmpty {
                    Text(bodyText)
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }

            if let progress {
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
        .padding(MoveMarkTheme.Spacing.panelPadding)
        .mmProofCardSurface(.standard, cornerRadius: 22)
    }
}
