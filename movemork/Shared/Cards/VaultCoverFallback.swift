//
//  VaultCoverFallback.swift
//  movemork
//
//  Mint placeholder covers when no preview image is available.
//

import SwiftUI

struct VaultCoverFallback: View {
    let style: VaultFallbackStyle
    let isPressed: Bool
    var isEmphasized: Bool = false

    var body: some View {
        ZStack {
            if isEmphasized {
                featuredCoverZone
            } else {
                standardCoverZone
            }
        }
        .opacity(isPressed ? 0.94 : 1.0)
    }

    private var featuredCoverZone: some View {
        ZStack {
            LinearGradient(
                colors: featuredBaseGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.primary.opacity(0.18),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 200
            )

            featuredStatusRows
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var featuredStatusRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                capsule("ROOM PROOF")
                capsule(style == .ready ? "READY" : "IN PROGRESS")
            }

            meter(width: 0.64)
            meter(width: 0.82)
        }
        .opacity(0.72)
    }

    private var featuredBaseGradient: [Color] {
        switch style {
        case .empty:
            return [MoveMarkTheme.Colors.cardRaised, MoveMarkTheme.Colors.cardRaised, MoveMarkTheme.Colors.appBackgroundRaised]
        case .started:
            return [MoveMarkTheme.Colors.cardRaised, MoveMarkTheme.Colors.cardRaised.opacity(0.8), MoveMarkTheme.Colors.primary.opacity(0.08)]
        case .ready:
            return [MoveMarkTheme.Colors.cardRaised, MoveMarkTheme.Colors.primary.opacity(0.12), MoveMarkTheme.Colors.cardRaised]
        }
    }

    private var standardCoverZone: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    capsule("VAULT")
                    capsule(style == .empty ? "NOT STARTED" : "ACTIVE")
                }

                meter(width: style == .ready ? 0.9 : (style == .started ? 0.65 : 0.42))
                meter(width: 0.58)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .opacity(0.65)
        }
    }

    private var gradientColors: [Color] {
        switch style {
        case .empty:
            return [MoveMarkTheme.Colors.appBackgroundRaised, MoveMarkTheme.Colors.cardRaised.opacity(0.5)]
        case .started:
            return [MoveMarkTheme.Colors.cardRaised.opacity(0.7), MoveMarkTheme.Colors.cardRaised]
        case .ready:
            return [MoveMarkTheme.Colors.cardRaised, MoveMarkTheme.Colors.primary.opacity(0.14)]
        }
    }

    private func capsule(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen.opacity(0.75))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(MoveMarkTheme.Colors.card.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 0.6)
            )
    }

    private func meter(width: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(MoveMarkTheme.Colors.cardStroke.opacity(0.8))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary.opacity(0.55))
                        .frame(width: proxy.size.width * width)
                }
        }
        .frame(height: 4)
    }
}
