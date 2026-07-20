//
//  MMSummaryCapsule.swift
//  movemork
//
//  MoveMark — Lightweight summary chip (e.g. "1 Property", "Recent").
//

import SwiftUI

struct MMSummaryCapsule: View {
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Text(value)
                .font(MoveMarkTheme.Typography.footnoteEmphasis)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(label)
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MoveMarkTheme.Colors.fieldFill)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.7), lineWidth: 1)
        )
    }
}
