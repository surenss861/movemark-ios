//
//  MoveMarkTheme.swift
//  movemork
//
//  MoveMark — Emerald Proof Vault (dark surfaces, light text, paper previews only).
//

import SwiftUI

enum MoveMarkTheme {
    enum Colors {
        // Shell
        static let appBackground = Color(red: 0.024, green: 0.071, blue: 0.051)           // #06120D
        static let appBackgroundRaised = Color(red: 0.031, green: 0.102, blue: 0.071)   // #081A12
        static let surface = Color(red: 0.047, green: 0.125, blue: 0.090)               // #0C2017

        // Cards
        static let card = Color(red: 0.063, green: 0.161, blue: 0.114)                  // #10291D
        static let cardRaised = Color(red: 0.078, green: 0.208, blue: 0.145)            // #143525
        static let cardStroke = Color(red: 0.141, green: 0.290, blue: 0.212)            // #244A36
        static let subtleStroke = Color(red: 0.102, green: 0.227, blue: 0.165)           // #1A3A2A

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

        // Brand
        static let primary = Color(red: 0.086, green: 0.639, blue: 0.290)               // #16A34A
        static let primaryPressed = Color(red: 0.059, green: 0.478, blue: 0.227)       // #0F7A3A
        static let primaryGreenDark = primaryPressed
        static let limeAccent = Color(red: 0.718, green: 0.969, blue: 0.455)           // #B7F774
        static let proofMint = Color(red: 0.545, green: 0.906, blue: 0.651)             // #8BE7A6
        static let accent = primary

        // Text (dark UI)
        static let textPrimary = Color(red: 0.949, green: 0.973, blue: 0.945)          // #F2F8F1
        static let textSecondary = Color(red: 0.659, green: 0.722, blue: 0.678)       // #A8B8AD
        static let textMuted = Color(red: 0.435, green: 0.514, blue: 0.463)             // #6F8376
        static let textOnPrimary = Color.white
        static let textOnDark = textPrimary
        static let textOnDarkMuted = textSecondary
        static let textOnLight = textPrimary
        static let textDarkGreen = proofMint
        static let textDeepGreen = limeAccent

        /// Report paper / photo preview only — never main card fill.
        static let paperSurface = Color(red: 0.949, green: 0.973, blue: 0.945)
        static let creamSurface = paperSurface
        static let whiteSurface = paperSurface

        static let divider = subtleStroke.opacity(0.85)
        static let fieldFill = Color(red: 0.055, green: 0.149, blue: 0.106)
        static let surfaceInset = fieldFill

        // Semantic
        static let semanticSuccess = primary
        static let semanticWarning = Color(red: 0.847, green: 0.604, blue: 0.118)        // #D89A1E
        static let semanticDanger = Color(red: 0.937, green: 0.357, blue: 0.357)        // #EF5B5B
    }

    enum Spacing {
        static let screenHorizontal: CGFloat = 24
        static let panelPadding: CGFloat = 18
        static let cornerRadius: CGFloat = 22
        static let fieldHeight: CGFloat = 58
        static let buttonHeight: CGFloat = 58
        static let heroButtonHeight: CGFloat = 68
        static let heroTopInset: CGFloat = 4

        static let scrollTailRootTabChrome: CGFloat = 32
        static let scrollTailFocusedFlow: CGFloat = 24
        static let vaultExpansionScrollExtra: CGFloat = 72
    }

    enum Typography {
        static let hero = Font.system(size: 40, weight: .bold, design: .default)
        static let heroLarge = Font.system(size: 44, weight: .bold, design: .default)
        static let screenTitle = Font.system(size: 28, weight: .bold, design: .default)
        static let cardTitle = Font.system(size: 20, weight: .bold, design: .default)
        static let cardValue = Font.system(size: 36, weight: .bold, design: .default)
        static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .default)

        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 17, weight: .medium, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let subheadlineMedium = Font.system(size: 15, weight: .semibold, design: .default)
        static let button = Font.system(size: 17, weight: .semibold, design: .default)
        static let footnote = Font.system(size: 13, weight: .medium, design: .default)
        static let caption = Font.system(size: 11, weight: .bold, design: .default)
    }
}

// MARK: - Emerald vault background

struct MMEmeraldBackground: View {
    /// Stronger hero-zone glow (Welcome, vault dashboard).
    var emphasizesHeroZone: Bool = false
    /// Stronger bottom bloom behind primary CTA.
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
                    MoveMarkTheme.Colors.primary.opacity(emphasizesHeroZone ? 0.22 : 0.12),
                    MoveMarkTheme.Colors.proofMint.opacity(emphasizesHeroZone ? 0.08 : 0.04),
                    .clear
                ],
                center: UnitPoint(x: 0.42, y: emphasizesHeroZone ? 0.32 : 0.22),
                startRadius: 16,
                endRadius: reduceMotion ? 260 : (emphasizesHeroZone ? 520 : 400)
            )

            proofGridLayer.opacity(emphasizesHeroZone ? 0.42 : 0.32)

            grainLayer.opacity(0.045)

            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.primary.opacity(emphasizesCTABloom ? 0.16 : 0.08),
                    MoveMarkTheme.Colors.limeAccent.opacity(0.03),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 1.0),
                startRadius: 20,
                endRadius: emphasizesCTABloom ? 380 : 300
            )

            edgeVignette
        }
        .ignoresSafeArea()
    }

    private var edgeVignette: some View {
        RadialGradient(
            colors: [
                .clear,
                MoveMarkTheme.Colors.appBackground.opacity(0.35),
                MoveMarkTheme.Colors.appBackground.opacity(0.72)
            ],
            center: .center,
            startRadius: 140,
            endRadius: 560
        )
    }

    private var proofGridLayer: some View {
        Canvas { context, size in
            let spacing: CGFloat = 26
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
                with: .color(MoveMarkTheme.Colors.cardStroke.opacity(0.28)),
                lineWidth: 0.5
            )
        }
        .allowsHitTesting(false)
    }

    private var grainLayer: some View {
        Canvas { context, size in
            let step: CGFloat = 3
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    if Int((x + y) / step) % 7 == 0 {
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(Color.white.opacity(0.04))
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
}
