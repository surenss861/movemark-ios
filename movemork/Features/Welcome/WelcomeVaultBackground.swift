//
//  WelcomeVaultBackground.swift
//  movemork
//
//  Welcome — calm vault atmosphere (no competing shapes).
//

import SwiftUI

struct WelcomeVaultBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    MoveMarkTheme.Colors.appBackgroundRaised,
                    MoveMarkTheme.Colors.appBackground,
                    MoveMarkTheme.Colors.surface
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.primary.opacity(0.2),
                    MoveMarkTheme.Colors.proofMint.opacity(0.05),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.34),
                startRadius: 24,
                endRadius: reduceMotion ? 220 : 320
            )

            proofGrid.opacity(0.28)
            grain.opacity(0.04)

            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.primary.opacity(0.12),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 1.0),
                startRadius: 20,
                endRadius: 300
            )

            RadialGradient(
                colors: [
                    .clear,
                    MoveMarkTheme.Colors.appBackground.opacity(0.65)
                ],
                center: .center,
                startRadius: 160,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }

    private var proofGrid: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(
                path,
                with: .color(MoveMarkTheme.Colors.cardStroke.opacity(0.2)),
                lineWidth: 0.5
            )
        }
        .allowsHitTesting(false)
    }

    private var grain: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    if Int((x + y) / 4) % 9 == 0 {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(.white.opacity(0.05))
                        )
                    }
                    x += 4
                }
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}
