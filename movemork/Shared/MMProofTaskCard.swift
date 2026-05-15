//
//  MMProofTaskCard.swift
//  movemork
//
//  Proof task — dark raised emerald row.
//

import SwiftUI

struct MMProofTaskCard: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil
    var showsChevron: Bool = false
    var tone: Tone = .warning

    enum Tone {
        case warning
        case action

        var iconFill: Color {
            switch self {
            case .warning: return MoveMarkTheme.Colors.semanticWarning.opacity(0.18)
            case .action: return MoveMarkTheme.Colors.primary.opacity(0.22)
            }
        }

        var iconColor: Color {
            switch self {
            case .warning: return MoveMarkTheme.Colors.semanticWarning
            case .action: return MoveMarkTheme.Colors.proofMint
            }
        }
    }

    var body: some View {
        Group {
            if let onAction {
                Button(action: onAction) { cardContent }
                    .buttonStyle(MMCardPressStyle())
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(tone.iconFill)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .stroke(MoveMarkTheme.Colors.subtleStroke, lineWidth: 1)
                    )
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(tone.iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(message)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            if let actionTitle {
                Text(actionTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textOnPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(MoveMarkTheme.Colors.primary)
                    .clipShape(Capsule())
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MoveMarkTheme.Colors.cardRaised)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.12), radius: 10, y: 4)
    }
}
