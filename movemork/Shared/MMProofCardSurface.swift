//
//  MMProofCardSurface.swift
//  movemork
//
//  Tactile emerald proof card surface — shared across flows.
//

import SwiftUI

enum MMProofCardSurface {
    case evidence
    case depositPayoff
    case standard
}

extension View {
    func mmProofCardSurface(_ kind: MMProofCardSurface, cornerRadius: CGFloat = 18) -> some View {
        modifier(MMProofCardSurfaceModifier(kind: kind, cornerRadius: cornerRadius))
    }
}

private struct MMProofCardSurfaceModifier: ViewModifier {
    let kind: MMProofCardSurface
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(topHighlight)
            .overlay(innerShadow)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }

    private var fill: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fillColor)
    }

    private var fillColor: Color {
        switch kind {
        case .evidence:
            return MoveMarkTheme.Colors.card.opacity(0.985)
        case .depositPayoff:
            return MoveMarkTheme.Colors.cardRaised.opacity(0.99)
        case .standard:
            return MoveMarkTheme.Colors.card
        }
    }

    private var topHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.17), Color.white.opacity(0.06), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.38)
                ),
                lineWidth: 1.1
            )
    }

    /// Subtle depth so cards read as glass on top of photos.
    private var innerShadow: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.black.opacity(kind == .depositPayoff ? 0.22 : 0.18), lineWidth: 1)
            .blur(radius: 2)
            .offset(y: 1.5)
            .mask(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        MoveMarkTheme.Colors.limeAccent.opacity(kind == .depositPayoff ? 0.28 : 0.22),
                        MoveMarkTheme.Colors.cardStroke.opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: kind == .depositPayoff ? 1.05 : 1.1
            )
    }

    private var shadowColor: Color {
        switch kind {
        case .evidence:
            return Color.black.opacity(0.38)
        case .depositPayoff:
            return Color.black.opacity(0.34)
        case .standard:
            return Color.black.opacity(0.28)
        }
    }

    private var shadowRadius: CGFloat {
        switch kind {
        case .evidence: return 18
        case .depositPayoff: return 14
        case .standard: return 12
        }
    }

    private var shadowY: CGFloat {
        switch kind {
        case .evidence: return 8
        case .depositPayoff: return 5
        case .standard: return 6
        }
    }
}
