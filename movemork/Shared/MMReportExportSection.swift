//
//  MMReportExportSection.swift
//  movemork
//
//  Move-out and dispute report cards. Same card as move-in; Pro lock changes the badge
//  and the action, not the layout.
//

import SwiftUI

struct MMReportExportSection: View {
    let sectionTitle: String
    var sectionSubtitle: String? = nil
    let statusLabel: String
    let statusTone: ProofStatusTone
    var metricsLine: String? = nil
    var footnote: String? = nil
    let primaryTitle: String
    var primaryEnabled: Bool = true
    var isProcessing: Bool = false
    var isProLocked: Bool = false
    var useQuietPrimaryWhenLocked: Bool = false
    var legalNote: String? = nil
    var generatedLine: String? = nil
    let onPrimary: () -> Void

    var body: some View {
        ProofReportCard(
                model: ProofReportModel(
                    reportTitle: sectionTitle,
                    metricsLine: metricsLine ?? sectionSubtitle,
                    statusLabel: isProLocked ? "Pro" : statusLabel,
                    statusTone: isProLocked ? .neutral : statusTone,
                    footnote: isProLocked
                        ? (useQuietPrimaryWhenLocked
                            ? "Bundle proof if your deposit is questioned."
                            : "Unlock with MoveMark Pro")
                        : footnote,
                    generatedLine: generatedLine
                ),
                primaryTitle: primaryTitle,
                onPrimary: onPrimary,
                primaryEnabled: primaryEnabled,
                primaryKind: primaryKind,
                isBright: !isProLocked && statusTone == .success,
                isProcessing: isProcessing,
                isCompact: true,
                legalNote: legalNote
            )
    }

    /// Solid green only for forward progress (make / retry). Viewing, upgrading and
    /// navigating elsewhere are secondary.
    private var primaryKind: MMButton.Kind {
        if isProLocked { return .secondary }
        switch statusTone {
        case .info, .danger: return .primary
        case .success, .warning, .neutral: return .secondary
        }
    }
}
