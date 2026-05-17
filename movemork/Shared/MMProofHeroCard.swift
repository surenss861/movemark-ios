//
//  MMProofHeroCard.swift
//  movemork
//
//  Vault proof folder card — calm progress, no dashboard chrome.
//

import SwiftUI

struct MMProofHeroCard: View {
    enum Style {
        case light
        case premium
    }

    let headline: String
    let nextLine: String
    let progress: Double
    var progressLabel: String? = nil
    let primaryTitle: String
    let onPrimary: () -> Void
    var style: Style = .premium

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double { min(1, max(0, progress)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                folderGlyph
                headlineBlock
            }

            progressBlock

            MMButton(
                title: primaryTitle,
                action: {
                    MMHaptics.soft()
                    onPrimary()
                },
                kind: .primary,
                size: .hero
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.8), lineWidth: 0.85)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 14, y: 6)
    }

    private var folderGlyph: some View {
        Image(systemName: "folder.fill")
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.85))
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.8))
            )
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Move-in proof")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.95))

            Text(headline)
                .font(MoveMarkTheme.Typography.cardTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(nextLine)
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.96))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.9))
                        .frame(height: 6)
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary.opacity(0.9))
                        .frame(width: max(8, geo.size.width * clampedProgress), height: 6)
                        .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clampedProgress)
                }
            }
            .frame(height: 6)

            if let progressLabel, !progressLabel.isEmpty {
                Text(progressLabel)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
        }
    }
}
