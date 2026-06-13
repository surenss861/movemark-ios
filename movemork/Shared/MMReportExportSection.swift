//
//  MMReportExportSection.swift
//  movemork
//
//  Secondary report cards — move-out and dispute packets.
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
    var legalNote: String? = nil
  let onPrimary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sectionTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .padding(.leading, 2)

            if let sectionSubtitle, !sectionSubtitle.isEmpty {
                Text(sectionSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }

            ProofReportCard(
                model: ProofReportModel(
                    reportTitle: sectionTitle,
                    metricsLine: metricsLine,
                    statusLabel: isProLocked ? "Pro feature" : statusLabel,
                    statusTone: isProLocked ? .neutral : statusTone,
                    footnote: isProLocked ? "Unlock with MoveMark Pro" : footnote
                ),
                primaryTitle: primaryTitle,
                onPrimary: onPrimary,
                primaryEnabled: primaryEnabled,
                isBright: !isProLocked && statusTone == .success,
                isProcessing: isProcessing,
                isCompact: true,
                legalNote: legalNote
            )
        }
    }
}
