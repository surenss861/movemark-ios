//
//  MMActionTile.swift
//  movemork
//
//  Primary vs secondary action tiles: Walkthrough dominant, others infrastructural.
//

import SwiftUI

struct MMActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = MoveMarkTheme.Colors.primary
    var isPrimary: Bool = false
    let action: () -> Void

    private var iconBoxSize: CGFloat { isPrimary ? 52 : 40 }
    private var iconSize: CGFloat { isPrimary ? 20 : 16 }
    private var cornerRadius: CGFloat { isPrimary ? 22 : 18 }
    private var minHeight: CGFloat { isPrimary ? 92 : 76 }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: isPrimary ? 16 : 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: isPrimary ? 18 : 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isPrimary
                                    ? [tint.opacity(0.22), tint.opacity(0.10)]
                                    : [MoveMarkTheme.Colors.fieldFill.opacity(0.95), MoveMarkTheme.Colors.fieldFill.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: isPrimary ? 18 : 14, style: .continuous)
                                .stroke(
                                    isPrimary ? tint.opacity(0.18) : MoveMarkTheme.Colors.cardStroke.opacity(0.5),
                                    lineWidth: 1
                                )
                        )
                        .frame(width: iconBoxSize, height: iconBoxSize)

                    Image(systemName: systemImage)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(isPrimary ? tint : MoveMarkTheme.Colors.textPrimary.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: isPrimary ? 5 : 3) {
                    Text(title)
                        .font(isPrimary ? .system(size: 18, weight: .semibold) : .system(size: 16, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(isPrimary ? .system(size: 15, weight: .regular) : .system(size: 14, weight: .regular))
                        .foregroundStyle(
                            isPrimary
                                ? MoveMarkTheme.Colors.textSecondary.opacity(0.92)
                                : MoveMarkTheme.Colors.textSecondary.opacity(0.76)
                        )
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(isPrimary ? tint.opacity(0.12) : MoveMarkTheme.Colors.cardRaised.opacity(0.5))
                        .frame(width: isPrimary ? 30 : 26, height: isPrimary ? 30 : 26)

                    Image(systemName: "chevron.right")
                        .font(MoveMarkTheme.Typography.tinyEmphasis)
                        .foregroundStyle(isPrimary ? tint : MoveMarkTheme.Colors.textSecondary.opacity(0.62))
                }
            }
            .padding(.horizontal, isPrimary ? 18 : 14)
            .padding(.vertical, isPrimary ? 16 : 13)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isPrimary
                            ? tint.opacity(0.26)
                            : MoveMarkTheme.Colors.cardStroke.opacity(0.55),
                        lineWidth: isPrimary ? 1.2 : 0.75
                    )
            )
        }
        .buttonStyle(MMActionTileStyle())
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isPrimary
                        ? [
                            MoveMarkTheme.Colors.card.opacity(1.0),
                            MoveMarkTheme.Colors.card.opacity(0.96)
                        ]
                        : [
                            MoveMarkTheme.Colors.card.opacity(0.94),
                            MoveMarkTheme.Colors.card.opacity(0.90)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

private struct MMActionTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
