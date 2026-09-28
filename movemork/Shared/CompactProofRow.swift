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
        MoveMarkTheme.Radius.row
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(MoveMarkTheme.Typography.rowTitle)
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
            .padding(.vertical, MoveMarkTheme.Spacing.rowVertical)
            .frame(minHeight: style == .settings ? 60 : 0, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(MoveMarkTheme.Surface.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MoveMarkTheme.Stroke.normal, lineWidth: 1)
            )
        }
        .buttonStyle(MMCardPressStyle())
    }
}
