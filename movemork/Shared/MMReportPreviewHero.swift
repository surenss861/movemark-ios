//
//  MMReportPreviewHero.swift
//  movemork
//
//  Reports anchor — proof assembling into a PDF artifact.
//

import SwiftUI

struct MMReportPreviewHero: View {
    enum State: Equatable {
        case loading
        case notReady
        case canMake
        case processing
        case ready
        case failed
    }

    let state: State
    var metricsLine: String? = nil
    let headline: String
    var footnote: String? = nil
    var proofChips: [String] = []
    let primaryTitle: String
    var isPrimaryDisabled: Bool = false
    var unlockPulse: Bool = false
    let onPrimary: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isDocumentBright: Bool {
        state == .ready
    }

  var body: some View {
        ProofReportCard(
            model: ProofReportModel(
                reportTitle: "Move-in report",
                metricsLine: metricsLine ?? headline,
                statusLabel: statusLabel,
                statusTone: statusTone,
                footnote: footnote
            ),
            primaryTitle: primaryTitle,
            onPrimary: {
                if isDocumentBright { MMHaptics.success() } else { MMHaptics.soft() }
                onPrimary()
            },
            primaryEnabled: !isPrimaryDisabled,
            isBright: isDocumentBright,
            isProcessing: state == .processing,
            proofChips: proofChips
        )
        .mmAppearRise(isVisible: state != .loading, delay: 0.08, offset: 6)
        .mmReportUnlockPulse(active: unlockPulse)
    }

    private var statusLabel: String {
        switch state {
        case .loading: return "Checking proof"
        case .notReady: return "Needs proof"
        case .canMake: return "Report can be made"
        case .processing: return "Building report"
        case .ready: return "Ready to share"
        case .failed: return "Failed"
        }
    }

    private var statusTone: ProofStatusTone {
        switch state {
        case .ready: return .success
        case .canMake: return .neutral
        case .processing, .loading: return .warning
        case .failed: return .danger
        case .notReady: return .warning
        }
    }
}
