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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MoveMarkTheme.Colors.fieldFill)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.7), lineWidth: 1)
        )
    }
}
