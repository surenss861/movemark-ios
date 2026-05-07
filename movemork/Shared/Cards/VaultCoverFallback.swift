//
//  VaultCoverFallback.swift
//  movemork
//
//  Non-featured + featured cover surfaces share the same “proof workspace” language.
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

    // MARK: - Featured: editorial cover slot with subtle vault-health signals.

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
                capsule(style == .ready ? "EXPORT READY" : "IN PROGRESS")
            }

            meter(width: 0.64)
            meter(width: 0.82)
        }
        .opacity(0.56)
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

    // MARK: - Non-featured: compact placeholder that still reads like a live vault.

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
            .opacity(0.5)
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

    private func capsule(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(Color.white.opacity(0.58))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func meter(width: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.white.opacity(0.1))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary.opacity(0.3))
                        .frame(width: proxy.size.width * width)
                }
        }
        .frame(height: 4)
    }
}
