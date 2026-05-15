//
//  VaultCoverExpandedTray.swift
//  movemork
//
//  Fold-out tray: metadata, progress, next step, primary action.
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
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
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
        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        .lineLimit(1)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(MoveMarkTheme.Colors.panelStroke)
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 1)
                    .fill(MoveMarkTheme.Colors.primary)
                    .frame(width: max(0, geo.size.width * content.progress), height: 3)
                    .animation(MMMotion.proofProgress, value: content.progress)
            }
        }
        .frame(height: 3)
    }

    private var primaryAction: some View {
        Button(action: content.onPrimaryAction) {
            Text(content.primaryActionTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(MoveMarkTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var trayBackground: some View {
        MoveMarkTheme.Colors.panelAlt
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(MoveMarkTheme.Colors.panelStroke)
                    .frame(height: 0.5)
            }
    }
}
