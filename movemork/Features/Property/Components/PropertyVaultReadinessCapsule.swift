//
//  PropertyVaultReadinessCapsule.swift
//  movemork
//
//  Compact floating readiness badge: score, ring, summary line.
//

import SwiftUI

struct PropertyVaultReadinessCapsule: View {
    let readinessScore: Int
    let summaryLine: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dispute readiness")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(readinessScore)%")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text(readinessBand)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            readinessScore >= 70
                                ? MoveMarkTheme.Colors.primary
                                : MoveMarkTheme.Colors.textSecondary
                        )
                }

                Text(summaryLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.86))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            ProgressRingView(
                progress: Double(readinessScore) / 100.0,
                size: 48,
                lineWidth: 3,
                label: nil
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MoveMarkTheme.Colors.panel.opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.52), lineWidth: 0.8)
        )
        .shadow(color: MoveMarkTheme.Colors.textPrimary.opacity(0.08), radius: 14, y: 7)
    }

    private var readinessBand: String {
        if readinessScore >= 70 { return "strong" }
        if readinessScore >= 40 { return "building" }
        return "early"
    }
}
