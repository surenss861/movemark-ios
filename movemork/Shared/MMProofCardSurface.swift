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
    /// Neutral charcoal — less green dashboard chrome (Evidence OS).
    case neutral
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
        case .neutral:
            return MoveMarkTheme.Colors.evidenceCard
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
                borderGradient,
                lineWidth: kind == .depositPayoff ? 1.05 : (kind == .neutral ? 0.75 : 1.1)
            )
    }

    private var borderGradient: LinearGradient {
        switch kind {
        case .neutral:
            return LinearGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [
                    MoveMarkTheme.Colors.limeAccent.opacity(kind == .depositPayoff ? 0.28 : 0.22),
                    MoveMarkTheme.Colors.cardStroke.opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        switch kind {
        case .evidence:
            return Color.black.opacity(0.38)
        case .depositPayoff:
            return Color.black.opacity(0.34)
        case .standard:
            return Color.black.opacity(0.18)
        case .neutral:
            return Color.black.opacity(0.14)
        }
    }

    private var shadowRadius: CGFloat {
        switch kind {
        case .evidence: return 14
        case .depositPayoff: return 8
        case .standard: return 6
        case .neutral: return 4
        }
    }

    private var shadowY: CGFloat {
        switch kind {
        case .evidence: return 6
        case .depositPayoff: return 3
        case .standard: return 3
        case .neutral: return 2
        }
    }
}
