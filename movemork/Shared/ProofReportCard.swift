//
//  ProofReportCard.swift
//  movemork
//
//  Report artifact card — document preview, honest status, proof metrics.
//

import SwiftUI

struct ProofReportModel {
    var reportTitle: String
    var metricsLine: String?
    var statusLabel: String
    var statusTone: ProofStatusTone = .neutral
    var footnote: String?
}

struct ProofReportCard: View {
    let model: ProofReportModel
    let primaryTitle: String
    let onPrimary: () -> Void
    var primaryEnabled: Bool = true
    var primaryKind: MMButton.Kind = .primary
    var isBright: Bool = false
    var isProcessing: Bool = false
    var isCompact: Bool = false
    var proofChips: [String] = []
    var legalNote: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let cardPadding: CGFloat = isCompact ? 12 : 14
        let cornerRadius: CGFloat = isCompact ? 16 : 20

        VStack(alignment: .leading, spacing: 0) {
            Text(model.reportTitle.uppercased())
                .font(MoveMarkTheme.Typography.microLabel)
                .tracking(0.7)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

            if let metricsLine = model.metricsLine, !metricsLine.isEmpty {
                Text(metricsLine)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .padding(.top, 4)
            }

            HStack(alignment: .top, spacing: 14) {
                ProofDocumentPreview(
                    large: !isCompact,
                    isBright: isBright,
                    isProcessing: isProcessing
                )
                VStack(alignment: .leading, spacing: 6) {
                    ProofStatusBadge(text: model.statusLabel, tone: model.statusTone)
                    if let footnote = model.footnote, !footnote.isEmpty {
                        Text(footnote)
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 10)

            if !proofChips.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(proofChips, id: \.self) { chip in
                        Text(chip)
                            .font(MoveMarkTheme.Typography.tinyMedium)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.85))
                            )
                    }
                }
                .padding(.top, 12)
            }

            if let legalNote, !legalNote.isEmpty {
                Text(legalNote)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .padding(.top, 10)
            }

            MMButton(
                title: primaryTitle,
                action: onPrimary,
                kind: primaryKind,
                size: .standard,
                isDisabled: !primaryEnabled
            )
            .padding(.top, 14)
        }
        .padding(cardPadding)
        .background(MoveMarkTheme.Colors.evidenceCard)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
