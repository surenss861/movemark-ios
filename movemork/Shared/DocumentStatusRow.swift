//
//  DocumentStatusRow.swift
//  movemork
//
//  MoveMark — Single document row with uploaded/missing state.
//

import SwiftUI

struct DocumentStatusRow: View {
    let title: String
    let subtitle: String
    let isPresent: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MoveMarkTheme.Colors.fieldFill)
                    .frame(width: 42, height: 42)

                Image(systemName: isPresent ? "doc.fill" : "doc")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isPresent ? MoveMarkTheme.Colors.accent : MoveMarkTheme.Colors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MoveMarkTheme.Typography.bodyMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }

            Spacer()

            MMPill(
                text: isPresent ? "Uploaded" : "Missing",
                tone: isPresent ? .success : .warning
            )
        }
        .padding(.vertical, 4)
    }
}
