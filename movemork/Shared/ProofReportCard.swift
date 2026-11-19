//
//  ProofReportCard.swift
//  movemork
//
//  A report is a document object: cover, status, record id, and one action.
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
    /// Short archival id, e.g. MM-RP-4C82. Omitted until a real export exists.
    var recordId: String? = nil
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
        VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
            HStack(alignment: .top, spacing: 14) {
                ProofDocumentIcon(
                    isBright: isBright,
                    isProcessing: isProcessing,
                    compact: isCompact
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.reportTitle.uppercased())
                        .font(MoveMarkTheme.Typography.kicker)
                        .tracking(1.05)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)

                    Text(model.statusLabel.uppercased())
                        .font(MoveMarkTheme.Typography.rowTitle)
                        .tracking(0.4)
                        .foregroundStyle(statusColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)

                    if let metricsText, !metricsText.isEmpty {
                        Text(metricsText)
                            .font(MoveMarkTheme.Typography.metadata)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let generated = model.generatedLine, !generated.isEmpty {
                        Text(generated)
                            .font(MoveMarkTheme.Typography.monoMeta)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    }

                    if let recordId = model.recordId, !recordId.isEmpty {
                        Text(recordId)
                            .font(MoveMarkTheme.Typography.monoMeta)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    }

                    if let footnote = model.footnote, !footnote.isEmpty {
                        Text(footnote)
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
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
        .padding(isCompact ? 14 : MoveMarkTheme.Spacing.panelPadding)
        .mmCaseFilePlate(cornerRadius: MoveMarkTheme.Radius.card, emphasis: !isCompact && isBright)
    }

    private var statusColor: Color {
        switch model.statusTone {
        case .success: MoveMarkTheme.Colors.primary
        case .warning: MoveMarkTheme.Colors.semanticWarning
        case .danger: MoveMarkTheme.Colors.semanticDanger
        case .info: MoveMarkTheme.Colors.semanticInfo
        case .neutral: MoveMarkTheme.Colors.textPrimary
        }
    }
}

/// Paper cover. The edge turns green only once the record is ready.
struct ProofDocumentIcon: View {
    var isBright: Bool = true
    var isProcessing: Bool = false
    var compact: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var width: CGFloat { compact ? 58 : 84 }
    private var height: CGFloat { compact ? 76 : 112 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(MoveMarkTheme.Colors.paperSurface.opacity(isBright ? 1 : 0.78))

            VStack(alignment: .leading, spacing: compact ? 5 : 7) {
                Text("MM")
                    .font(.system(size: compact ? 11 : 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(MoveMarkTheme.Colors.textOnLight.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                rule(width: compact ? 28 : 44)
                rule(width: compact ? 34 : 52)
                rule(width: compact ? 22 : 36)

                Spacer(minLength: 0)

                Text(isProcessing ? "FILE" : (isBright ? "PDF" : "FILE"))
                    .font(.system(size: compact ? 9 : 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(MoveMarkTheme.Colors.textOnLight.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(compact ? 8 : 12)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(MoveMarkTheme.Colors.textOnLight.opacity(0.12), lineWidth: 0.5)

            Rectangle()
                .fill(edgeColor)
                .frame(width: 3)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .phaseAnimator(isProcessing && !reduceMotion ? [1.0, 0.78] : [1.0]) { content, phase in
            content.opacity(phase)
        } animation: { _ in
            .easeInOut(duration: 0.9)
        }
        .accessibilityHidden(true)
    }

    private var edgeColor: Color {
        if isBright { return MoveMarkTheme.Colors.primary }
        if isProcessing { return MoveMarkTheme.Colors.semanticWarning }
        return MoveMarkTheme.Colors.textOnLight.opacity(0.28)
    }

    private func rule(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(MoveMarkTheme.Colors.textOnLight.opacity(isProcessing ? 0.18 : 0.28))
            .frame(width: width, height: 2)
    }
}
