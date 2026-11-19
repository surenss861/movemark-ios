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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.titleToSubtitle) {
                Text(title)
                    .font(MoveMarkTheme.Typography.pageTitle)
                    .tracking(-0.7)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(MoveMarkTheme.Typography.body)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 4)

            trailing()
                .padding(.top, 2)
        }
        .padding(.bottom, 4)
    }
}

extension MMProofSectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Small letterspaced label that opens a section — "NEXT ACTIONS", "EXPORT HISTORY".
struct MMSectionLabel<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(MoveMarkTheme.Typography.sectionLabel)
                .tracking(0.9)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 4)
    }
}

struct MMProofHeaderAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(MoveMarkTheme.Typography.bodySmallEmphasis)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(MoveMarkTheme.Surface.raised)
                )
                .overlay(
                    Circle()
                        .stroke(MoveMarkTheme.Stroke.interactive, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New vault")
    }
}
