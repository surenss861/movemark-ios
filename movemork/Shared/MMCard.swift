//
//  MMCard.swift
//  movemork
//
//  MoveMark — Clean financial card surfaces (white / mint tiers).
//

import SwiftUI

struct MMCard<Content: View>: View {
    enum Tone {
        case elevated
        case standard
        case quiet
        /// Mint-tinted panel for proof rows and dense lists.
        case artifact

        var fill: Color {
            switch self {
            case .elevated, .standard:
                return MoveMarkTheme.Colors.panel
            case .quiet:
                return MoveMarkTheme.Colors.panel.opacity(0.98)
            case .artifact:
                return MoveMarkTheme.Colors.panelAlt
            }
        }

        var strokeOpacity: Double {
            switch self {
            case .elevated:
                return 1.0
            case .standard:
                return 0.92
            case .quiet, .artifact:
                return 0.78
            }
        }

        var shadowOpacity: Double {
            switch self {
            case .elevated:
                return 0.06
            case .standard:
                return 0.04
            case .quiet, .artifact:
                return 0.02
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
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: MoveMarkTheme.Spacing.cornerRadius,
                style: .continuous
            )
        )
        .shadow(
            color: MoveMarkTheme.Colors.textPrimary.opacity(tone.shadowOpacity),
            radius: tone == .elevated ? 16 : 10,
            x: 0,
            y: tone == .elevated ? 6 : 3
        )
    }
}
