//
//  PhotoStripView.swift
//  movemork
//
//  MoveMark — Horizontal photo strip (thumb placeholders + count).
//

import SwiftUI

struct PhotoStripView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<min(max(count, 1), 4), id: \.self) { idx in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(idx == 0 ? 0.10 : 0.04))
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(idx == 0 ? MoveMarkTheme.Colors.accent : MoveMarkTheme.Colors.panelStroke, lineWidth: 1)
                    )
            }

            if count > 4 {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MoveMarkTheme.Colors.fieldFill)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text("+\(count - 4)")
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    )
            }
        }
    }
}
