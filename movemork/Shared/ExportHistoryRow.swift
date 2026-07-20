//
//  ExportHistoryRow.swift
//  movemork
//
//  Compact export history row — document-first, not photo cards.
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
        HStack(alignment: .center, spacing: 12) {
            ProofDocumentPreview(
                large: false,
                isBright: canShare,
                isProcessing: isProcessing
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(dateLine)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)

                ProofStatusBadge(text: statusLabel, tone: statusTone)
            }

            Spacer(minLength: 0)

            if canShare {
                MMButton(
                    title: "Share",
                    action: onShare,
                    kind: .quiet,
                    size: .compact,
                    expandsToFillWidth: false
                )
            } else if canRetry, let onRetry {
                MMButton(
                    title: "Retry",
                    action: onRetry,
                    kind: .quiet,
                    size: .compact,
                    expandsToFillWidth: false
                )
            }
        }
        .padding(.vertical, 4)
    }
}
