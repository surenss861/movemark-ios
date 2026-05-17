//
//  MMProofSectionHeader.swift
//  movemork
//

import SwiftUI

struct MMProofSectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.titleToSubtitle) {
                Text(title)
                    .font(MoveMarkTheme.Typography.screenTitle)
                    .tracking(-0.6)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(MoveMarkTheme.Typography.screenSubtitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
    }
}

extension MMProofSectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct MMProofHeaderAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.85))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New vault")
    }
}
