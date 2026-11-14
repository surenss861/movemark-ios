//
//  ProofTaskCard.swift
//  movemork
//

import SwiftUI

struct ProofTaskCard: View {
    let title: String
    let reason: String
    let action: () -> Void
    var statusLabel: String?
    var statusTone: ProofStatusTone = .neutral
    var showChevron: Bool = true

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MoveMarkTheme.Typography.bodySmallEmphasis)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(reason)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let statusLabel {
                    ProofStatusBadge(text: statusLabel, tone: statusTone)
                }
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(MoveMarkTheme.Typography.footnoteEmphasis)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, MoveMarkTheme.Spacing.rowVertical)
            .background(MoveMarkTheme.Surface.raised)
            .overlay(
                RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.row, style: .continuous)
                    .stroke(MoveMarkTheme.Stroke.normal, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.row, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.row, style: .continuous))
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}
