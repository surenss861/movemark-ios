//
//  PropertyVaultSecondaryTools.swift
//  movemork
//
//  MoveMark — quiet lifecycle actions inside a rental workspace.
//

import SwiftUI

struct PropertyVaultSecondaryTools: View {
    let openIssuesCount: Int
    let completedRooms: Int
    let readinessScore: Int
    let exportsSubtitle: String
    let pulseDisputeTile: Bool
    let pulseExportsTile: Bool

    let onMaintenance: () -> Void
    let onMoveOut: () -> Void
    let onDisputeBuilder: () -> Void
    let onExports: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MMSectionLabel("Rental lifecycle")

            VStack(spacing: 0) {
                actionRow(
                    title: "Maintenance",
                    subtitle: openIssuesCount > 0
                        ? (openIssuesCount == 1 ? "1 open issue" : "\(openIssuesCount) open issues")
                        : "Record repairs, problems, and follow-up",
                    systemImage: "wrench.and.screwdriver",
                    onTap: onMaintenance
                )

                divider

                actionRow(
                    title: "Move-out",
                    subtitle: completedRooms > 0
                        ? "Compare move-in proof with final condition"
                        : "Build move-in proof before comparing condition",
                    systemImage: "arrow.left.arrow.right",
                    onTap: onMoveOut
                )

                divider

                actionRow(
                    title: "Case builder",
                    subtitle: readinessScore >= 70
                        ? "Assemble captured proof for a dispute"
                        : "Keep building proof before you need it",
                    systemImage: "doc.text",
                    isHighlighted: pulseDisputeTile,
                    onTap: onDisputeBuilder
                )

                divider

                actionRow(
                    title: "Reports",
                    subtitle: exportsSubtitle,
                    systemImage: "doc.richtext",
                    isHighlighted: pulseExportsTile,
                    onTap: onExports
                )
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.card, style: .continuous)
                    .fill(MoveMarkTheme.Surface.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.card, style: .continuous)
                    .stroke(MoveMarkTheme.Stroke.normal, lineWidth: 1)
            )
        }
    }

    private var divider: some View {
        Divider()
            .overlay(MoveMarkTheme.Stroke.normal)
    }

    private func actionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isHighlighted: Bool = false,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: systemImage)
                    .font(MoveMarkTheme.Typography.bodyMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MoveMarkTheme.Typography.rowTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text(subtitle)
                        .font(MoveMarkTheme.Typography.metadata)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if isHighlighted {
                    Circle()
                        .fill(MoveMarkTheme.Colors.primary)
                        .frame(width: 6, height: 6)
                }

                Image(systemName: "chevron.right")
                    .font(MoveMarkTheme.Typography.metadata)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
            .padding(.vertical, MoveMarkTheme.Spacing.rowVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
