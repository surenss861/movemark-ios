//
//  ProofReportCard.swift
//  movemork
//
//  Compact current-report card: small document icon, title, one status badge, a metrics
//  line, when it was generated, and one action. Optional secondary action sits beside the
//  primary (reserved for "Make updated report").
//

import SwiftUI

struct ProofReportModel {
    var reportTitle: String
    var metricsLine: String?
    var statusLabel: String
    var statusTone: ProofStatusTone = .neutral
    var footnote: String?
    /// "Generated Sep 23 · 8:29 PM" — shown when a report exists.
    var generatedLine: String? = nil
}

struct ProofReportCard: View {
    let model: ProofReportModel
    let primaryTitle: String
    let onPrimary: () -> Void
    var primaryEnabled: Bool = true
    var primaryKind: MMButton.Kind = .primary
    var isBright: Bool = false
    var isProcessing: Bool = false
    var isCompact: Bool = true
    var proofChips: [String] = []
    var legalNote: String?
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil

    private var metricsText: String? {
        if !proofChips.isEmpty { return proofChips.joined(separator: " · ") }
        return model.metricsLine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ProofDocumentIcon(isBright: isBright, isProcessing: isProcessing)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(model.reportTitle)
                            .font(MoveMarkTheme.Typography.rowTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        ProofStatusBadge(text: model.statusLabel, tone: model.statusTone)
                    }

                    if let metricsText, !metricsText.isEmpty {
                        Text(metricsText)
                            .font(MoveMarkTheme.Typography.metadata)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let generated = model.generatedLine, !generated.isEmpty {
                        Text(generated)
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    }

                    if let footnote = model.footnote, !footnote.isEmpty {
                        Text(footnote)
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let legalNote, !legalNote.isEmpty {
                Text(legalNote)
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }

            HStack(spacing: 10) {
                MMButton(
                    title: primaryTitle,
                    action: onPrimary,
                    kind: primaryKind,
                    size: .inline,
                    isDisabled: !primaryEnabled
                )

                if let secondaryTitle, let onSecondary {
                    MMButton(
                        title: secondaryTitle,
                        action: onSecondary,
                        kind: .tertiary,
                        size: .inline,
                        expandsToFillWidth: false
                    )
                }
            }
        }
        .padding(MoveMarkTheme.Spacing.panelPadding)
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

/// 44pt document glyph — replaces the large stacked-paper illustration, which took room
/// without saying anything the title and badge don't.
struct ProofDocumentIcon: View {
    var isBright: Bool = true
    var isProcessing: Bool = false
    var size: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(MoveMarkTheme.Surface.interactive)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isBright ? MoveMarkTheme.Stroke.selected : MoveMarkTheme.Stroke.normal, lineWidth: 1)
            )
            .overlay(
                Image(systemName: isBright ? "doc.text.fill" : "doc.text")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(isBright ? MoveMarkTheme.Colors.primary : MoveMarkTheme.Colors.textSecondary)
                    .symbolEffect(.pulse, isActive: isProcessing && !reduceMotion)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
