//
//  FactChip.swift
//  movemork
//
//  MoveMark — Key-value chip for vault hero (photos, issues, rooms).
//

import SwiftUI

struct FactChip: View {
    let title: String
    let value: String
    var accent: Color = MoveMarkTheme.Colors.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(MoveMarkTheme.Typography.cardTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(title)
                .font(MoveMarkTheme.Typography.caption)
                .tracking(1.0)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(MoveMarkTheme.Colors.fieldFill)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
