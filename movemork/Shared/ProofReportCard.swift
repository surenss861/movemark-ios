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
    var isBright: Bool = false
    var isProcessing: Bool = false
    var proofChips: [String] = []
    var legalNote: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.reportTitle.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

            if let metricsLine = model.metricsLine, !metricsLine.isEmpty {
                Text(metricsLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .padding(.top, 4)
            }

            HStack(alignment: .top, spacing: 14) {
                ProofDocumentPreview(
                    large: true,
                    isBright: isBright,
                    isProcessing: isProcessing
                )
                VStack(alignment: .leading, spacing: 6) {
                    ProofStatusBadge(text: model.statusLabel, tone: model.statusTone)
                    if let footnote = model.footnote, !footnote.isEmpty {
                        Text(footnote)
                            .font(.system(size: 12, weight: .medium))
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
                            .font(.system(size: 11, weight: .medium))
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .padding(.top, 10)
            }

            MMButton(
                title: primaryTitle,
                action: onPrimary,
                kind: .primary,
                size: .standard,
                isDisabled: !primaryEnabled
            )
            .padding(.top, 14)
        }
        .padding(14)
        .background(MoveMarkTheme.Colors.evidenceCard)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
