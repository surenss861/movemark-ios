//
//  MMReportHeroCard.swift
//  movemork
//
//  Reports hero — dark emerald card, light paper object inside.
//

import SwiftUI

enum MMReportCardStatus {
    case notReady
    case readyToMake
    case readyToShare
    case processing
    case failed

    var label: String {
        switch self {
        case .notReady: return "Report not ready"
        case .readyToMake: return "Move-in report ready"
        case .readyToShare: return "Report ready"
        case .processing: return "Processing"
        case .failed: return "Failed"
        }
    }

    var pillTone: MMPill.Tone {
        switch self {
        case .notReady: return .warning
        case .readyToMake, .readyToShare: return .success
        case .processing: return .warning
        case .failed: return .danger
        }
    }

    var usesPremiumReady: Bool {
        self == .readyToMake || self == .readyToShare
    }
}

struct MMReportHeroCard: View {
    let title: String
    let metrics: String?
    let status: MMReportCardStatus
    let primaryTitle: String
    let onPrimary: () -> Void
    var unlockPulse: Bool = false

    private var usesPremiumReady: Bool { status.usesPremiumReady }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                documentStackPreview
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(MoveMarkTheme.Typography.cardTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    if let metrics, !metrics.isEmpty {
                        Text(metrics)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    }

                    MMPill(text: status.label, tone: status.pillTone)
                }
                Spacer(minLength: 0)
            }

            MMButton(
                title: primaryTitle,
                action: {
                    if usesPremiumReady { MMHaptics.success() } else { MMHaptics.soft() }
                    onPrimary()
                },
                kind: .primary,
                size: .hero
            )
        }
        .padding(20)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(
            color: MoveMarkTheme.Colors.primary.opacity(usesPremiumReady ? 0.28 : 0.14),
            radius: 18,
            y: 8
        )
        .mmReportUnlockPulse(active: unlockPulse)
    }

    private var documentStackPreview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MoveMarkTheme.Colors.cardRaised.opacity(0.85))
                .frame(width: 52, height: 68)
                .offset(x: 8, y: -6)
                .rotationEffect(.degrees(6))

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.9))
                .frame(width: 54, height: 72)
                .offset(x: 4, y: -3)
                .rotationEffect(.degrees(3))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MoveMarkTheme.Colors.paperSurface)
                .frame(width: 62, height: 82)
                .shadow(color: MoveMarkTheme.Colors.primary.opacity(usesPremiumReady ? 0.25 : 0.12), radius: 10, y: 4)
                .overlay {
                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(usesPremiumReady ? MoveMarkTheme.Colors.primary : MoveMarkTheme.Colors.semanticWarning)
                            .frame(width: 30, height: 5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(0.12))
                            .frame(width: 38, height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(0.08))
                            .frame(width: 34, height: 4)
                        Spacer(minLength: 0)
                        Image(systemName: usesPremiumReady ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(
                                usesPremiumReady
                                    ? MoveMarkTheme.Colors.primary
                                    : MoveMarkTheme.Colors.semanticWarning
                            )
                    }
                    .padding(10)
                }
        }
        .frame(width: 72, height: 80)
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: usesPremiumReady
                ? [MoveMarkTheme.Colors.cardRaised, MoveMarkTheme.Colors.card, MoveMarkTheme.Colors.surface]
                : [MoveMarkTheme.Colors.card, MoveMarkTheme.Colors.surface, MoveMarkTheme.Colors.surface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                usesPremiumReady
                    ? MoveMarkTheme.Colors.limeAccent.opacity(0.3)
                    : MoveMarkTheme.Colors.semanticWarning.opacity(0.4),
                lineWidth: 1
            )
    }
}
