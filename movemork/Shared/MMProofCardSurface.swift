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
            return MoveMarkTheme.Colors.card.opacity(0.9)
        case .depositPayoff:
            return MoveMarkTheme.Colors.cardRaised.opacity(0.94)
        case .standard:
            return MoveMarkTheme.Colors.card
        }
    }

    private var topHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.03), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.4)
                ),
                lineWidth: 1
            )
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.8), lineWidth: 1)
    }

    private var shadowColor: Color {
        Color.black.opacity(kind == .depositPayoff ? 0.3 : 0.28)
    }

    private var shadowRadius: CGFloat {
        kind == .depositPayoff ? 10 : 12
    }

    private var shadowY: CGFloat {
        kind == .depositPayoff ? 4 : 6
    }
}
