//
//  SectionLabel.swift
//  movemork
//
//  MoveMark — Uppercase section label for cards.
//

import SwiftUI

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MoveMarkTheme.Typography.caption)
            .tracking(1.1)
            .foregroundStyle(MoveMarkTheme.Colors.primary)
            .textCase(.uppercase)
    }
}
