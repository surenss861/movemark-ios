//
//  MoveMarkTheme.swift
//  movemork
//
//  MoveMark — Dark premium design system.
//

import SwiftUI

enum MoveMarkTheme {
    enum Colors {
        static let background = Color(red: 0.03, green: 0.03, blue: 0.04)
        static let panel = Color(red: 0.08, green: 0.08, blue: 0.09)
        static let panelStroke = Color.white.opacity(0.08)

        static let primary = Color(red: 0.25, green: 0.66, blue: 0.45)   // emerald
        static let primaryPressed = Color(red: 0.20, green: 0.58, blue: 0.39)

        static let textPrimary = Color(red: 0.95, green: 0.93, blue: 0.90) // ivory
        static let textSecondary = Color(red: 0.60, green: 0.57, blue: 0.54) // stone
        static let accent = Color(red: 0.81, green: 0.68, blue: 0.43) // muted gold

        static let divider = Color.white.opacity(0.10)
        static let fieldFill = Color(red: 0.05, green: 0.05, blue: 0.06)

        // MARK: Semantic (meaningful color only — not decoration)

        /// Proof saved, export ready, verified, resolved.
        static let semanticSuccess = primary

        /// Missing records, open maintenance, needs attention.
        static let semanticWarning = Color(red: 0.93, green: 0.72, blue: 0.32)

        /// Failed upload, destructive action, server-side export failure.
        static let semanticDanger = Color(red: 0.94, green: 0.36, blue: 0.38)

        /// Dark-mode depth: surface slightly above `background`, below `panel`.
        static let surfaceInset = Color(red: 0.10, green: 0.10, blue: 0.11)
    }

    enum Spacing {
        static let screenHorizontal: CGFloat = 24
        static let panelPadding: CGFloat = 18
        static let cornerRadius: CGFloat = 22
        static let fieldHeight: CGFloat = 58
        static let buttonHeight: CGFloat = 58

        /// Scroll tail when the root tab bar is visible (Vaults / Exports / Account roots only).
        static let scrollTailRootTabChrome: CGFloat = 32

        /// Scroll tail when the tab bar is hidden (property detail, walkthrough, capture, move-out, etc.).
        static let scrollTailFocusedFlow: CGFloat = 24

        /// Extra scroll bottom inset on Vaults when the featured card expansion tray is open.
        static let vaultExpansionScrollExtra: CGFloat = 72
    }

    /// SF Pro (system font). Sharper, more serious; not bubbly.
    enum Typography {
        // Sharper, more serious display
        static let hero = Font.system(size: 32, weight: .heavy, design: .default)
        static let heroLarge = Font.system(size: 36, weight: .heavy, design: .default)
        static let screenTitle = Font.system(size: 28, weight: .bold, design: .default)
        static let cardTitle = Font.system(size: 20, weight: .bold, design: .default)
        static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .default)

        // Body
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 17, weight: .medium, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let subheadlineMedium = Font.system(size: 15, weight: .medium, design: .default)
        static let button = Font.system(size: 17, weight: .semibold, design: .default)
        static let footnote = Font.system(size: 13, weight: .medium, design: .default)
        static let caption = Font.system(size: 11, weight: .bold, design: .default)
    }
}
