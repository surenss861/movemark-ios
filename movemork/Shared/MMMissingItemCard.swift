//
//  MMMissingItemCard.swift
//  movemork
//
//  Amber callout for missing lease/docs — plain renter language.
//

import SwiftUI

struct MMMissingItemCard: View {
    let title: String
    let message: String
    let actionTitle: String
    let onAction: () -> Void

    var body: some View {
        Button(action: onAction) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(MoveMarkTheme.Colors.semanticWarning.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(message)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Text(actionTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textOnPrimary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(MoveMarkTheme.Colors.semanticWarning.opacity(0.92))
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MoveMarkTheme.Colors.card.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.semanticWarning.opacity(0.35), lineWidth: 0.75)
            )
        }
        .buttonStyle(MMCardPressStyle())
    }
}
