//
//  MMStatPill.swift
//  movemork
//
//  MoveMark — Value + label stat tile for summary cards.
//

import SwiftUI

struct MMStatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(MoveMarkTheme.Typography.bodySmallEmphasis)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(label)
                .font(MoveMarkTheme.Typography.tinyEmphasis)
                .tracking(0.8)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(MoveMarkTheme.Colors.fieldFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
        )
    }
}
