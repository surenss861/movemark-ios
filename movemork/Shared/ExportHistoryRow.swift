//
//  ExportHistoryRow.swift
//  movemork
//
//  Archival export row: title, date, and a status badge only when the export is not ready.
//  Ready rows open on tap; failed rows offer Retry.
//

import SwiftUI

struct ExportHistoryRow: View {
    let title: String
    let dateLine: String
    let statusLabel: String
    let statusTone: ProofStatusTone
    var isProcessing: Bool = false
    var canShare: Bool = false
    var canRetry: Bool = false
    let onShare: () -> Void
    var onRetry: (() -> Void)? = nil

    var body: some View {
        Button {
            if canShare { onShare() } else if canRetry { onRetry?() }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // A ready row is one line; a row with a badge moves its date under the
                // title so neither the title nor the badge truncates.
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(1)

                    if !canShare {
                        Text(dateLine)
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                if canShare {
                    Text(dateLine)
                        .font(MoveMarkTheme.Typography.caption)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        .lineLimit(1)
                } else {
                    ProofStatusBadge(text: canRetry ? "Failed · Retry" : statusLabel, tone: statusTone)
                }

                Image(systemName: "chevron.right")
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(canShare || canRetry ? 1 : 0))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canShare && !canRetry)
        .accessibilityElement(children: .combine)
        .accessibilityHint(canShare ? "Opens the report" : (canRetry ? "Retries the export" : ""))
    }
}
