//
//  TimelineRow.swift
//  movemork
//
//  MoveMark — Timeline row for issue detail and history.
//

import SwiftUI

struct TimelineRow: View {
    let title: String
    let value: String
    var isEmphasized: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isEmphasized ? MoveMarkTheme.Colors.primary : MoveMarkTheme.Colors.accent.opacity(0.9))
                    .frame(width: 8, height: 8)

                Rectangle()
                    .fill(MoveMarkTheme.Colors.panelStroke)
                    .frame(width: 1, height: 28)
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(MoveMarkTheme.Typography.caption)
                    .tracking(1.0)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .textCase(.uppercase)

                Text(value)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}
