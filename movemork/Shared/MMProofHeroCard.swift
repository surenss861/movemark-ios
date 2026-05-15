//
//  MMProofHeroCard.swift
//  movemork
//
//  Dominant vault proof hero — verified record on emerald.
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                proofGlyph
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
        .padding(20)
        .background { cardBackground }
        .overlay { proofPattern }
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.25), radius: 22, y: 10)
        .safeAreaPadding(.top, MoveMarkTheme.Spacing.heroTopInset)
    }

    private var proofPattern: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                Circle()
                    .stroke(MoveMarkTheme.Colors.limeAccent.opacity(0.08), lineWidth: 1)
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: geo.size.width * 0.2, y: -geo.size.width * 0.15)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.35), lineWidth: 0.8)
                    .frame(width: 72, height: 92)
                    .rotationEffect(.degrees(12))
                    .offset(x: geo.size.width * 0.58, y: geo.size.height * 0.12)
            }
        }
        .allowsHitTesting(false)
    }

    private var proofGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MoveMarkTheme.Colors.cardRaised.opacity(0.9))
                .frame(width: 52, height: 64)
                .offset(x: 6, y: 6)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MoveMarkTheme.Colors.limeAccent.opacity(0.1))
                .frame(width: 48, height: 58)
                .offset(x: -4, y: -4)

            Circle()
                .fill(MoveMarkTheme.Colors.limeAccent.opacity(0.14))
                .frame(width: 48, height: 48)
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.limeAccent)
        }
        .frame(width: 56, height: 56)
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Proof progress")
                .font(MoveMarkTheme.Typography.caption)
                .tracking(0.9)
                .foregroundStyle(MoveMarkTheme.Colors.limeAccent.opacity(0.9))
                .textCase(.uppercase)

            Text(headline)
                .font(MoveMarkTheme.Typography.hero)
                .tracking(-0.5)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .shadow(color: MoveMarkTheme.Colors.limeAccent.opacity(0.12), radius: 0, y: 0)
                .fixedSize(horizontal: false, vertical: true)

            Text(nextLine)
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 10)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [MoveMarkTheme.Colors.primary, MoveMarkTheme.Colors.limeAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geo.size.width * clampedProgress), height: 10)
                        .shadow(color: MoveMarkTheme.Colors.limeAccent.opacity(0.45), radius: 6, y: 0)
                        .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clampedProgress)
                }
            }
            .frame(height: 10)

            if let progressLabel, !progressLabel.isEmpty {
                Text(progressLabel)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
        }
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [
                MoveMarkTheme.Colors.cardRaised,
                MoveMarkTheme.Colors.card,
                MoveMarkTheme.Colors.surface
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        MoveMarkTheme.Colors.limeAccent.opacity(0.35),
                        MoveMarkTheme.Colors.cardStroke.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}
