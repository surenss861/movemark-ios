//
//  MMCard.swift
//  movemork
//
//  MoveMark — Tactile emerald card surfaces.
//

import SwiftUI

struct MMCard<Content: View>: View {
    enum Tone {
        case elevated
        case standard
        case quiet
        case artifact
        case cream
        case inset
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
        .background(cardFill)
        .overlay(topHighlight)
        .overlay(cardStroke)
        .clipShape(
            RoundedRectangle(
                cornerRadius: MoveMarkTheme.Spacing.cornerRadius,
                style: .continuous
            )
        )
        .shadow(
            color: MoveMarkTheme.Colors.primary.opacity(shadowOpacity),
            radius: shadowRadius,
            x: 0,
            y: shadowY
        )
    }

    private var cardFill: some View {
        RoundedRectangle(cornerRadius: MoveMarkTheme.Spacing.cornerRadius, style: .continuous)
            .fill(fillColor)
    }

    private var topHighlight: some View {
        RoundedRectangle(cornerRadius: MoveMarkTheme.Spacing.cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(highlightOpacity),
                        Color.white.opacity(0.04),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.35)
                ),
                lineWidth: 1.2
            )
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: MoveMarkTheme.Spacing.cornerRadius, style: .continuous)
            .stroke(MoveMarkTheme.Colors.cardStroke.opacity(strokeOpacity), lineWidth: 1)
    }

    private var fillColor: Color {
        switch tone {
        case .elevated, .cream:
            return MoveMarkTheme.Colors.cardRaised
        case .standard:
            return MoveMarkTheme.Colors.card
        case .quiet:
            return MoveMarkTheme.Colors.card.opacity(0.92)
        case .artifact:
            return MoveMarkTheme.Colors.surface
        case .inset:
            return MoveMarkTheme.Colors.fieldFill
        }
    }

    private var strokeOpacity: Double {
        switch tone {
        case .elevated, .cream: return 1.0
        case .standard: return 0.88
        case .quiet, .artifact, .inset: return 0.7
        }
    }

    private var highlightOpacity: Double {
        switch tone {
        case .elevated, .cream: return 0.16
        case .standard: return 0.11
        default: return 0.07
        }
    }

    private var shadowOpacity: Double {
        switch tone {
        case .elevated, .cream: return 0.26
        case .standard: return 0.16
        case .quiet, .artifact, .inset: return 0.08
        }
    }

    private var shadowRadius: CGFloat {
        tone == .elevated || tone == .cream ? 20 : 12
    }

    private var shadowY: CGFloat {
        tone == .elevated || tone == .cream ? 9 : 5
    }
}
