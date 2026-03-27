//
//  MMEditorialHeader.swift
//  movemork
//
//  MoveMark — Standard editorial header: eyebrow, title, subtitle, gold rule.
//

import SwiftUI

struct MMEditorialHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    /// Default 42pt; use smaller for long titles (e.g. property address).
    var titleFont: Font = .system(size: 42, weight: .bold)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MoveMarkTheme.Colors.accent)

            Text(title)
                .font(titleFont)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(subtitle)
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Rectangle()
                .fill(MoveMarkTheme.Colors.accent)
                .frame(width: 40, height: 3)
                .clipShape(Capsule())
                .padding(.top, 4)
        }
    }
}
