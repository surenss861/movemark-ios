//
//  MMEmptyState.swift
//  movemork
//
//  Calm empty / guidance surface — one icon, clear title, supportive copy, optional CTA.
//

import SwiftUI

struct MMEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var primaryTitle: String?
    var primaryAction: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String,
        primaryTitle: String? = nil,
        primaryAction: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
    }

    var body: some View {
        MMCard(tone: .quiet, padding: 22, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.accent.opacity(0.92))
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(MoveMarkTheme.Typography.cardTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text(message)
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let primaryTitle, let primaryAction {
                    MMButton(title: primaryTitle, action: primaryAction, kind: .primary, size: .standard)
                        .padding(.top, 4)
                }
            }
        }
    }
}
