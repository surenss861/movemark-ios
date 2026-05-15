//
//  MoveMarkTheme.swift
//  movemork
//
//  MoveMark — Wise-inspired green + white financial-protection design system.
//

import SwiftUI

enum MoveMarkTheme {
    enum Colors {
        // Surfaces (60% white/cream, 30% mint, 10% strong green)
        static let background = Color(red: 0.973, green: 0.984, blue: 0.961)   // #F8FBF5
        static let backgroundAlt = Color(red: 0.965, green: 0.980, blue: 0.953) // #F6FAF3
        static let panel = Color.white
        static let panelAlt = Color(red: 0.918, green: 0.969, blue: 0.910)     // #EAF7E8
        static let panelStroke = Color(red: 0.843, green: 0.910, blue: 0.847)  // #D7E8D8
        static let mint = Color(red: 0.875, green: 0.961, blue: 0.890)       // #DFF5E3

        // Brand green
        static let primary = Color(red: 0.173, green: 0.765, blue: 0.420)    // #2CC36B
        static let primaryPressed = Color(red: 0.137, green: 0.647, blue: 0.353)

        // Text
        static let textPrimary = Color(red: 0.063, green: 0.125, blue: 0.082)  // #102015
        static let textSecondary = Color(red: 0.369, green: 0.420, blue: 0.380) // #5E6B61
        static let textOnPrimary = Color.white
        static let textDarkGreen = Color(red: 0.071, green: 0.239, blue: 0.145) // #123D25
        static let textDeepGreen = Color(red: 0.024, green: 0.208, blue: 0.122) // #06351F

        /// Editorial eyebrow / accent rule — brand green (replaces gold).
        static let accent = primary

        static let divider = panelStroke.opacity(0.85)
        static let fieldFill = mint.opacity(0.55)
        static let surfaceInset = panelAlt

        // MARK: Semantic

        static let semanticSuccess = primary
        static let semanticWarning = Color(red: 0.961, green: 0.722, blue: 0.294) // #F5B84B
        static let semanticDanger = Color(red: 0.851, green: 0.290, blue: 0.290)  // #D94A4A
    }

    enum Spacing {
        static let screenHorizontal: CGFloat = 24
        static let panelPadding: CGFloat = 18
        static let cornerRadius: CGFloat = 22
        static let fieldHeight: CGFloat = 58
        static let buttonHeight: CGFloat = 58

        static let scrollTailRootTabChrome: CGFloat = 32
        static let scrollTailFocusedFlow: CGFloat = 24
        static let vaultExpansionScrollExtra: CGFloat = 72
    }

    enum Typography {
        static let hero = Font.system(size: 34, weight: .heavy, design: .default)
        static let heroLarge = Font.system(size: 38, weight: .heavy, design: .default)
        static let screenTitle = Font.system(size: 28, weight: .bold, design: .default)
        static let cardTitle = Font.system(size: 20, weight: .bold, design: .default)
        static let cardValue = Font.system(size: 28, weight: .bold, design: .default)
        static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .default)

        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 17, weight: .medium, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let subheadlineMedium = Font.system(size: 15, weight: .medium, design: .default)
        static let button = Font.system(size: 17, weight: .semibold, design: .default)
        static let footnote = Font.system(size: 13, weight: .medium, design: .default)
        static let caption = Font.system(size: 11, weight: .bold, design: .default)
    }
}
