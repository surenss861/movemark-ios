//
//  MMProofListRow.swift
//  movemork
//

import SwiftUI

struct MMProofListRow: View {
    enum Style {
        case standard
        case settings
    }

    let title: String
    let subtitle: String
    var meta: String? = nil
    var style: Style = .standard
    let onTap: () -> Void

    private var cornerRadius: CGFloat {
        style == .settings ? 22 : 16
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let meta, !meta.isEmpty {
                        Text(meta)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
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
