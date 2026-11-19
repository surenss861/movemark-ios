//
//  MMCard.swift
//  movemork
//
//  MoveMark — card surfaces. Neutral raised fill, hairline stroke, no green glow.
//  `elevated` is the hero card (radius 24); everything else uses the card radius.
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
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var radius: CGFloat {
        tone == .elevated ? MoveMarkTheme.Radius.hero : MoveMarkTheme.Radius.card
    }

    private var cardFill: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fillColor)
    }

    private var topHighlight: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
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
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(MoveMarkTheme.Colors.cardStroke.opacity(strokeOpacity), lineWidth: 1)
    }

    private var fillColor: Color {
        switch tone {
        case .elevated, .cream, .standard:
            return MoveMarkTheme.Surface.raised
        case .quiet:
            return MoveMarkTheme.Surface.raised.opacity(0.85)
        case .artifact:
            return MoveMarkTheme.Surface.interactive
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
        case .elevated, .cream: return 0.08
        default: return 0.04
        }
    }
}
