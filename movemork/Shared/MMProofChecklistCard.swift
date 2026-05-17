//
//  MMProofChecklistCard.swift
//  movemork
//

import SwiftUI

struct MMProofChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let state: State

    enum State {
        case complete
        case incomplete
        case locked
    }
}

struct MMProofChecklistCard: View {
    let title: String
    let items: [MMProofChecklistItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.vertical, 10)
                    }
                    checklistRow(item)
                }
            }
        }
        .padding(MoveMarkTheme.Spacing.panelPadding)
        .mmProofCardSurface(.standard, cornerRadius: 20)
    }

    private func checklistRow(_ item: MMProofChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName(for: item.state))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor(for: item.state))
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        item.state == .locked
                            ? MoveMarkTheme.Colors.textSecondary.opacity(0.75)
                            : MoveMarkTheme.Colors.textPrimary
                    )

                Text(item.detail)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func iconName(for state: MMProofChecklistItem.State) -> String {
        switch state {
        case .complete: return "checkmark.circle.fill"
        case .incomplete: return "circle"
        case .locked: return "lock.fill"
        }
    }

    private func iconColor(for state: MMProofChecklistItem.State) -> Color {
        switch state {
        case .complete: return MoveMarkTheme.Colors.primary
        case .incomplete: return MoveMarkTheme.Colors.semanticWarning.opacity(0.78)
        case .locked: return MoveMarkTheme.Colors.textMuted
        }
    }
}
