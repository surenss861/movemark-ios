//
//  VaultCoverExpandedTray.swift
//  movemork
//
//  Fold-out continuation: one metadata row, progress, next step, one primary action.
//

import SwiftUI

struct VaultCoverExpandedTray: View {
    let content: VaultCoverExpansionContent

    private let trayPadding: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            metadataRow
            progressBar
            if let next = content.nextRoomLine, !next.isEmpty {
                Text(next)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.78))
            }
            primaryAction
        }
        .padding(.horizontal, trayPadding)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(trayBackground)
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            Text(content.roomsText)
            Text("·")
            Text(content.openIssuesText)
            if let last = content.lastUpdated {
                Text("·")
                Text(last)
            }
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.65))
        .lineLimit(1)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 2)
                RoundedRectangle(cornerRadius: 1)
                    .fill(MoveMarkTheme.Colors.primary.opacity(0.6))
                    .frame(width: max(0, geo.size.width * content.progress), height: 2)
                    .animation(MMMotion.proofProgress, value: content.progress)
            }
        }
        .frame(height: 2)
    }

    private var primaryAction: some View {
        Button(action: content.onPrimaryAction) {
            Text(content.primaryActionTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var trayBackground: some View {
        Color(white: 0.09)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.01))
                    .frame(height: 1),
                alignment: .top
            )
    }
}
