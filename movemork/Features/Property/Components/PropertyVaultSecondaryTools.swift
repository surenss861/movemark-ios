//
//  PropertyVaultSecondaryTools.swift
//  movemork
//
//  Quiet command tiles: Maintenance, Move-out, Case builder, Exports.
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

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            compactTool(
                title: "Maintenance",
                subtitle: openIssuesCount > 0
                    ? (openIssuesCount == 1 ? "1 open issue" : "\(openIssuesCount) open issues")
                    : "Track property issues",
                systemImage: "wrench.and.screwdriver.fill",
                onTap: onMaintenance
            )

            compactTool(
                title: "Move-out",
                subtitle: completedRooms > 0
                    ? "Compare before and after"
                    : "Use with move-in proof",
                systemImage: "arrow.2.circlepath",
                onTap: onMoveOut
            )

            compactTool(
                title: "Case builder",
                subtitle: readinessScore >= 70
                    ? "Build dispute packet"
                    : "Assemble captured proof",
                systemImage: "doc.text.fill",
                isPulsing: pulseDisputeTile,
                onTap: onDisputeBuilder
            )

            compactTool(
                title: "Exports",
                subtitle: exportsSubtitle,
                systemImage: "square.and.arrow.up",
                isPulsing: pulseExportsTile,
                onTap: onExports
            )
        }
    }

    private func compactTool(
        title: String,
        subtitle: String,
        systemImage: String,
        isPulsing: Bool = false,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MoveMarkTheme.Colors.mint.opacity(0.55))
                            .frame(width: 36, height: 36)

                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.88))
                    }

                    Spacer()

                    if isPulsing {
                        Circle()
                            .fill(MoveMarkTheme.Colors.primary.opacity(0.9))
                            .frame(width: 7, height: 7)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.8))
                        .lineLimit(2)
                        .frame(minHeight: 30, alignment: .topLeading)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MoveMarkTheme.Colors.panel.opacity(0.84))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isPulsing
                            ? MoveMarkTheme.Colors.primary.opacity(0.20)
                            : MoveMarkTheme.Colors.panelStroke.opacity(0.42),
                        lineWidth: isPulsing ? 1.0 : 0.8
                    )
            )
            .shadow(
                color: MoveMarkTheme.Colors.textPrimary.opacity(isPulsing ? 0.10 : 0.05),
                radius: isPulsing ? 14 : 8,
                y: isPulsing ? 6 : 3
            )
            .scaleEffect(isPulsing ? 1.012 : 1.0)
            .animation(.easeInOut(duration: 0.22), value: isPulsing)
        }
        .buttonStyle(.plain)
    }
}
