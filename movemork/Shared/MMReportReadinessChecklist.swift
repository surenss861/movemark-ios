//
//  MMReportReadinessChecklist.swift
//  movemork
//
//  Secondary proof checklist — lighter than the report preview hero.
//

import SwiftUI

struct MMReportReadinessChecklist: View {
    let items: [MMProofChecklistItem]
    var appeared: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Proof checklist")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.vertical, 6)
                    }

                    checklistRow(item)
                        .mmAppearRise(isVisible: appeared, delay: 0.04 + Double(index) * 0.03, offset: 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .mmProofCardSurface(.neutral, cornerRadius: 16)
        }
    }

    private func checklistRow(_ item: MMProofChecklistItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName(for: item.state))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor(for: item.state))
                .frame(width: 18, height: 18)
                .contentTransition(.symbolEffect(.replace))
                .animation(MMMotion.statusMorph, value: item.state)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        item.state == .locked
                            ? MoveMarkTheme.Colors.textMuted
                            : MoveMarkTheme.Colors.textPrimary.opacity(0.92)
                    )

                Text(item.detail)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
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
        case .complete: return MoveMarkTheme.Colors.primary.opacity(0.9)
        case .incomplete: return MoveMarkTheme.Colors.textMuted.opacity(0.75)
        case .locked: return MoveMarkTheme.Colors.textMuted.opacity(0.45)
        }
    }
}
