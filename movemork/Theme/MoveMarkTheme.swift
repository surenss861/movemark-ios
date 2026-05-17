//
//  MoveMarkTheme.swift
//  movemork
//
//  MoveMark — Dark Rental Proof Desk (warm charcoal, calm green, paper artifacts).
//

import SwiftUI

enum MoveMarkTheme {
    enum Colors {
        // Shell — warm charcoal green
        static let appBackground = Color(red: 0.031, green: 0.075, blue: 0.059)           // #08130F
        static let appBackgroundRaised = Color(red: 0.051, green: 0.102, blue: 0.082)   // #0D1A15
        static let surface = Color(red: 0.071, green: 0.137, blue: 0.106)               // #12231B

        // Cards
        static let card = Color(red: 0.071, green: 0.137, blue: 0.106)                  // #12231B
        static let cardRaised = Color(red: 0.090, green: 0.165, blue: 0.129)            // #172A21
        static let cardStroke = Color(red: 0.125, green: 0.220, blue: 0.169)            // subtle edge
        static let subtleStroke = Color(red: 0.102, green: 0.188, blue: 0.145)

        // Legacy aliases
        static let background = appBackground
        static let backgroundAlt = appBackgroundRaised
        static let backgroundDeep = surface
        static let deepCard = card
        static let deepCardAlt = cardRaised
        static let darkSurface = surface
        static let forestGreen = Color(red: 0.039, green: 0.125, blue: 0.082)
        static let panel = card
        static let panelAlt = cardRaised
        static let panelStroke = cardStroke
        static let softBorder = subtleStroke
        static let mint = cardRaised
        static let mintSurface = cardRaised

        // Brand — calm green, lime only for tiny success accents
        static let primary = Color(red: 0.129, green: 0.722, blue: 0.400)               // #21B866
        static let primaryPressed = Color(red: 0.094, green: 0.588, blue: 0.310)       // #18A957-ish pressed
        static let primaryGreenDark = primaryPressed
        static let limeAccent = Color(red: 0.608, green: 0.788, blue: 0.604)           // muted sage accent
        static let proofMint = Color(red: 0.545, green: 0.722, blue: 0.600)
        static let accent = primary

        // Text (dark UI)
        static let textPrimary = Color(red: 0.949, green: 0.973, blue: 0.945)
        static let textSecondary = Color(red: 0.659, green: 0.722, blue: 0.678)
        static let textMuted = Color(red: 0.435, green: 0.514, blue: 0.463)
        static let textOnPrimary = Color.white
        static let textOnDark = textPrimary
        static let textOnDarkMuted = textSecondary
        static let textOnLight = Color(red: 0.12, green: 0.18, blue: 0.14)
        static let textDarkGreen = proofMint
        static let textDeepGreen = proofMint

        /// Report / lease preview only — warm paper, never main card fill.
        static let paperSurface = Color(red: 0.910, green: 0.937, blue: 0.898)          // #E8EFE5
        static let creamSurface = paperSurface
        static let whiteSurface = paperSurface

        /// Muted warm sage for thumbnails on dark cards.
        static let artifactPaper = Color(red: 0.867, green: 0.910, blue: 0.855)         // #DDE8DA

        static let divider = subtleStroke.opacity(0.75)
        static let fieldFill = Color(red: 0.055, green: 0.118, blue: 0.090)
        static let surfaceInset = fieldFill

        // Semantic
        static let semanticSuccess = primary
        static let semanticWarning = Color(red: 0.847, green: 0.604, blue: 0.118)
        static let semanticDanger = Color(red: 0.937, green: 0.357, blue: 0.357)
    }

    enum Spacing {
        static let screenHorizontal: CGFloat = 24
        static let panelPadding: CGFloat = 18
        static let cornerRadius: CGFloat = 22
        static let fieldHeight: CGFloat = 58
        static let buttonHeight: CGFloat = 58
        static let heroButtonHeight: CGFloat = 68
        static let heroTopInset: CGFloat = 4

        static let scrollTailRootTabChrome: CGFloat = 96
        static let scrollTailFocusedFlow: CGFloat = 24
        static let vaultExpansionScrollExtra: CGFloat = 72
    }

    enum Typography {
        static let hero = Font.system(size: 34, weight: .bold, design: .default)
        static let heroLarge = Font.system(size: 38, weight: .bold, design: .default)
        static let screenTitle = Font.system(size: 28, weight: .bold, design: .default)
        static let cardTitle = Font.system(size: 20, weight: .bold, design: .default)
        static let cardValue = Font.system(size: 28, weight: .bold, design: .default)
        static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .default)

        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 17, weight: .medium, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let subheadlineMedium = Font.system(size: 15, weight: .semibold, design: .default)
        static let button = Font.system(size: 17, weight: .semibold, design: .default)
        static let footnote = Font.system(size: 13, weight: .medium, design: .default)
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
    }
}

// MARK: - Rental proof desk background

struct MMEmeraldBackground: View {
    var emphasizesHeroZone: Bool = false
    var emphasizesCTABloom: Bool = false

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
                    MoveMarkTheme.Colors.primary.opacity(emphasizesHeroZone ? 0.08 : 0.04),
                    MoveMarkTheme.Colors.proofMint.opacity(emphasizesHeroZone ? 0.03 : 0.02),
                    .clear
                ],
                center: UnitPoint(x: 0.42, y: emphasizesHeroZone ? 0.28 : 0.2),
                startRadius: 20,
                endRadius: reduceMotion ? 240 : (emphasizesHeroZone ? 420 : 340)
            )

            proofGridLayer.opacity(emphasizesHeroZone ? 0.08 : 0.05)

            grainLayer.opacity(0.03)

            if emphasizesCTABloom {
                RadialGradient(
                    colors: [
                        MoveMarkTheme.Colors.primary.opacity(0.06),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 1.0),
                    startRadius: 24,
                    endRadius: 280
                )
            }

            edgeVignette
        }
        .ignoresSafeArea()
    }

    private var edgeVignette: some View {
        RadialGradient(
            colors: [
                .clear,
                MoveMarkTheme.Colors.appBackground.opacity(0.28),
                MoveMarkTheme.Colors.appBackground.opacity(0.55)
            ],
            center: .center,
            startRadius: 160,
            endRadius: 560
        )
    }

    private var proofGridLayer: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28
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
                with: .color(MoveMarkTheme.Colors.cardStroke.opacity(0.18)),
                lineWidth: 0.45
            )
        }
        .allowsHitTesting(false)
    }

    private var grainLayer: some View {
        Canvas { context, size in
            let step: CGFloat = 4
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    if Int((x + y) / step) % 9 == 0 {
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(Color.white.opacity(0.025))
                        )
                    }
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

struct MMProofShellBackground: View {
    var emphasizesHeroZone: Bool = false
    var emphasizesCTABloom: Bool = false

    var body: some View {
        MMEmeraldBackground(
            emphasizesHeroZone: emphasizesHeroZone,
            emphasizesCTABloom: emphasizesCTABloom
        )
    }
}

extension View {
    func mmEmeraldBackground(heroFocus: Bool = false, ctaBloom: Bool = false) -> some View {
        background(
            MMEmeraldBackground(
                emphasizesHeroZone: heroFocus,
                emphasizesCTABloom: ctaBloom
            )
        )
    }

    func mmProofShellBackground(heroFocus: Bool = false, ctaBloom: Bool = false) -> some View {
        mmEmeraldBackground(heroFocus: heroFocus, ctaBloom: ctaBloom)
    }

    /// Keeps scroll content below status bar / TestFlight chrome.
    func mmScrollContentTopInset(_ extra: CGFloat = 0) -> some View {
        safeAreaPadding(.top, extra)
    }
}
