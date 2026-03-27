//
//  VaultCoverFallback.swift
//  movemork
//
//  Non-featured: subtle placeholder. Featured: hero cover zone — surface is the idea, not empty-state graphic.
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

    // MARK: - Featured: editorial cover slot — two-zone depth, directional light, no placeholder icon.

    private var featuredCoverZone: some View {
        ZStack {
            // Base: richer tonal separation so it doesn’t read as flat gray.
            LinearGradient(
                colors: featuredBaseGradient,
                startPoint: .top,
                endPoint: .bottom
            )

            // Key light: one strong top-left so it reads as “stage” / hero image slot.
            RadialGradient(
                colors: [
                    Color.white.opacity(0.28),
                    Color.white.opacity(0.06),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 200
            )

            // Soft horizon: mid-zone transition so upper half reads as distinct “cover” plane.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.44),
                    .init(color: Color.black.opacity(0.1), location: 0.5),
                    .init(color: .clear, location: 0.56),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Edge falloff: corners and bottom pull in so the center reads as the focal area.
            RadialGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.35)
                ],
                center: .bottom,
                startRadius: 40,
                endRadius: 260
            )

            // No placeholder icon for featured — the surface is the hero.
        }
    }

    private var featuredBaseGradient: [Color] {
        switch style {
        case .empty:
            return [
                Color(white: 0.14),
                Color(white: 0.09),
                Color(white: 0.06)
            ]
        case .started:
            return [
                Color(white: 0.13),
                Color(white: 0.08),
                MoveMarkTheme.Colors.primary.opacity(0.04)
            ]
        case .ready:
            return [
                Color(white: 0.14),
                Color(white: 0.08),
                MoveMarkTheme.Colors.primary.opacity(0.06)
            ]
        }
    }

    // MARK: - Non-featured: standard placeholder treatment.

    private var standardCoverZone: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.16),
                    Color.white.opacity(0.04),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 140
            )

            RadialGradient(
                colors: [.clear, Color.black.opacity(0.18)],
                center: .center,
                startRadius: 30,
                endRadius: 160
            )

            RadialGradient(
                colors: [.clear, Color.black.opacity(0.5)],
                center: .bottom,
                startRadius: 20,
                endRadius: 180
            )

            // Quiet structure only — no “missing media” placeholder icon.
            frameMotif.opacity(0.018)
        }
    }

    private var gradientColors: [Color] {
        switch style {
        case .empty:
            return [Color(white: 0.17), Color(white: 0.11), Color(white: 0.07)]
        case .started:
            return [Color(white: 0.16), MoveMarkTheme.Colors.primary.opacity(0.06), Color(white: 0.08)]
        case .ready:
            return [Color(white: 0.17), MoveMarkTheme.Colors.primary.opacity(0.08), Color(white: 0.07)]
        }
    }

    private var frameMotif: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(.white, lineWidth: 1)
            .frame(width: 100, height: 64)
            .offset(y: -12)
    }
}
