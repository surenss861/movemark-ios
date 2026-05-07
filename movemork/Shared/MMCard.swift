//
//  MMCard.swift
//  movemork
//
//  MoveMark — Elevated / standard / quiet surface tiers.
//

import SwiftUI

struct MMCard<Content: View>: View {
    enum Tone {
        case elevated
        case standard
        case quiet
        /// Dense lists / proof rows: lifted from background, calm stroke (artifact-like).
        case artifact

        var fill: Color {
            switch self {
            case .elevated:
                return MoveMarkTheme.Colors.panel.opacity(0.98)
            case .standard:
                return MoveMarkTheme.Colors.panel.opacity(0.94)
            case .quiet:
                return MoveMarkTheme.Colors.panel.opacity(0.82)
            case .artifact:
                return MoveMarkTheme.Colors.surfaceInset.opacity(0.96)
            }
        }

        var strokeOpacity: Double {
            switch self {
            case .elevated:
                return 0.95
            case .standard:
                return 0.75
            case .quiet:
                return 0.45
            case .artifact:
                return 0.58
            }
        }

        var shadowOpacity: Double {
            switch self {
            case .elevated:
                return 0.20
            case .standard:
                return 0.10
            case .quiet:
                return 0.0
            case .artifact:
                return 0.08
            }
        }
    }

    let tone: Tone
    let padding: CGFloat
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(
        tone: Tone = .standard,
        padding: CGFloat = MoveMarkTheme.Spacing.panelPadding,
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.padding = padding
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(padding)
        .background(tone.fill)
        .overlay(
            RoundedRectangle(
                cornerRadius: MoveMarkTheme.Spacing.cornerRadius,
                style: .continuous
            )
            .stroke(
                MoveMarkTheme.Colors.panelStroke.opacity(tone.strokeOpacity),
                lineWidth: (tone == .quiet || tone == .artifact) ? 0.8 : 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: MoveMarkTheme.Spacing.cornerRadius,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(tone.shadowOpacity),
            radius: tone == .elevated ? 18 : (tone == .artifact ? 12 : 10),
            x: 0,
            y: tone == .elevated ? 8 : (tone == .artifact ? 5 : 4)
        )
    }
}
