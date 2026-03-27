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
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(label)
                .font(.system(size: 11, weight: .bold))
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
                .stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 1)
        )
    }
}
