//
//  MoveMarkLight.swift
//  movemork
//
//  @file Light-first tokens for the redesign (Proof first; other screens adopt them as they're rebuilt)
//  @domain design-system
//  @status wip
//  @see [[VISUAL_STANDARD]] — canonical references: design-refs/proof.jpg, reports.jpg, account.jpg
//

import SwiftUI

extension MoveMarkTheme {
    /// Warm white surfaces, charcoal text, green only as a signal. No glow, no dark emerald.
    enum Light {
        /// App background behind sheets and grouped lists — warm very light gray.
        static let background = Color(red: 0.957, green: 0.953, blue: 0.941)        // #F4F3F0
        /// Raised sheet / grouped surface.
        static let surface = Color.white
        /// Quiet fill for metric rows, placeholders and inactive chips.
        static let fill = Color(red: 0.925, green: 0.922, blue: 0.910)              // #ECEBE8
        static let textPrimary = Color(red: 0.110, green: 0.110, blue: 0.118)        // #1C1C1E
        static let textSecondary = Color(red: 0.420, green: 0.420, blue: 0.440)      // #6B6B70
        static let textTertiary = Color(red: 0.600, green: 0.600, blue: 0.620)
        static let hairline = Color.black.opacity(0.07)
        /// MoveMark green for the one primary action. Dark text on it (white on green fails contrast).
        static let accent = MoveMarkTheme.Colors.primary
        static let onAccent = Color(red: 0.035, green: 0.110, blue: 0.067)           // #091C11
        /// Soft green wash for "done" / Pro states.
        static let accentWash = MoveMarkTheme.Colors.primary.opacity(0.12)
        static let attention = Color(red: 0.780, green: 0.520, blue: 0.090)

        static let sheetRadius: CGFloat = 28
        static let tileRadius: CGFloat = 18
        /// Barely-there depth: surfaces separate by tone first, shadow second.
        static func softShadow<V: View>(_ view: V) -> some View {
            view.shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        }
    }
}
