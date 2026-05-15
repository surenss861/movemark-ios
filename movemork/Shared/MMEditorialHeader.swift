//
//  MMEditorialHeader.swift
//  movemork
//
//  MoveMark — Standard header: eyebrow, title, subtitle, green rule.
//

import SwiftUI

struct MMEditorialHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var titleFont: Font = .system(size: 36, weight: .bold)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MoveMarkTheme.Colors.primary)

            Text(title)
                .font(titleFont)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(subtitle)
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(MoveMarkTheme.Colors.primary)
                .frame(width: 40, height: 3)
                .clipShape(Capsule())
                .padding(.top, 4)
        }
    }
}
