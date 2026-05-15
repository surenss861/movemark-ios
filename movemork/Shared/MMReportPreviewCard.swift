//
//  MMReportPreviewCard.swift
//  movemork
//
//  Signature MoveMark component: report preview + readiness + one CTA.
//

import SwiftUI

struct MMReportPreviewCard: View {
    enum Status {
        case notReady
        case readyToMake
        case readyToShare
        case processing
        case failed

        var label: String {
            switch self {
            case .notReady: return "Report not ready"
            case .readyToMake: return "Move-in report ready"
            case .readyToShare: return "Report ready"
            case .processing: return "Processing"
            case .failed: return "Failed"
            }
        }

        var pillTone: MMPill.Tone {
            switch self {
            case .notReady: return .warning
            case .readyToMake, .readyToShare: return .success
            case .processing: return .warning
            case .failed: return .danger
            }
        }
    }

    let title: String
    let metrics: String?
    let status: Status
    let primaryTitle: String
    let onPrimary: () -> Void
    /// Soft lift when report becomes ready (Reports unlock moment).
    var unlockPulse: Bool = false

    var body: some View {
        MMCard(tone: .artifact, padding: 18, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(MoveMarkTheme.Typography.cardTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                        if let metrics, !metrics.isEmpty {
                            Text(metrics)
                                .font(MoveMarkTheme.Typography.footnote)
                                .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen)
                        }
                    }

                    Spacer(minLength: 0)

                    MMPill(text: status.label, tone: status.pillTone)
                }

                MMButton(
                    title: primaryTitle,
                    action: {
                        MMHaptics.soft()
                        onPrimary()
                    },
                    kind: .primary,
                    size: .standard
                )
            }
        }
        .mmReportUnlockPulse(active: unlockPulse)
    }
}

