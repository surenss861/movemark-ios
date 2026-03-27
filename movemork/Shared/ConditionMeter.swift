//
//  ConditionMeter.swift
//  movemork
//
//  MoveMark — 1–5 condition bar for room detail.
//

import SwiftUI

struct ConditionMeter: View {
    let rating: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONDITION")
                .font(MoveMarkTheme.Typography.caption)
                .tracking(1.2)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            HStack(spacing: 5) {
                ForEach(1...5, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(idx <= rating ? Color.orange.opacity(0.95) : Color.white.opacity(0.08))
                        .frame(width: 24, height: 4)
                }
            }
        }
    }
}
