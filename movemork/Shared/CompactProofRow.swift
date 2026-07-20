//
//  CompactProofRow.swift
//  movemork
//
//  Compact tappable row for rentals, exports, and settings-adjacent lists.
//

import SwiftUI

enum CompactProofRowStyle {
    case standard
    case settings
}

struct CompactProofRow: View {
    let title: String
    let subtitle: String
    var meta: String? = nil
    var style: CompactProofRowStyle = .standard
    var trailingSystemName: String = "chevron.right"
    let onTap: () -> Void

    private var cornerRadius: CGFloat {
        style == .settings ? 22 : 16
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(MoveMarkTheme.Typography.bodySmallEmphasis)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let meta, !meta.isEmpty {
                        Text(meta)
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: trailingSystemName)
                    .font(MoveMarkTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: style == .settings ? 72 : 0, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(MoveMarkTheme.Colors.card.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(MMCardPressStyle())
    }
}
