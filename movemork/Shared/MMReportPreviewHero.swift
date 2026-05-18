//
//  MMReportPreviewHero.swift
//  movemork
//
//  Reports anchor — proof assembling into a PDF, not a dashboard card.
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
        state == .canMake || state == .ready
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                documentPreview
                VStack(alignment: .leading, spacing: 8) {
                    if let metricsLine, !metricsLine.isEmpty {
                        Text(metricsLine)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }

                    Text(headline)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .mmRowStatusTransition(value: headline)

                    if let footnote, !footnote.isEmpty {
                        Text(footnote)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    MMPill(text: statusLabel, tone: statusTone)
                }

                Spacer(minLength: 0)
            }

            if !proofChips.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(proofChips, id: \.self) { chip in
                        proofChip(chip)
                    }
                }
            }

            MMButton(
                title: primaryTitle,
                action: {
                    if isDocumentBright { MMHaptics.success() } else { MMHaptics.soft() }
                    onPrimary()
                },
                kind: .primary,
                size: .standard,
                isDisabled: isPrimaryDisabled
            )
            .mmAppearRise(isVisible: state != .loading, delay: 0.12, offset: 4)
        }
        .padding(18)
        .mmProofCardSurface(.neutral, cornerRadius: 22)
        .brightness(isDocumentBright ? 0.04 : 0)
        .mmReportUnlockPulse(active: unlockPulse)
    }

    private var statusLabel: String {
        switch state {
        case .loading: return "Checking proof"
        case .notReady: return "Needs more proof"
        case .canMake: return "Can make report"
        case .processing: return "Building report"
        case .ready: return "Report ready"
        case .failed: return "Failed"
        }
    }

    private var statusTone: MMPill.Tone {
        switch state {
        case .canMake, .ready: return .success
        case .processing, .loading: return .warning
        case .failed: return .danger
        case .notReady: return .warning
        }
    }

    private var documentPreview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MoveMarkTheme.Colors.evidenceCardRaised.opacity(0.9))
                .frame(width: 58, height: 88)
                .offset(x: 10, y: -8)
                .rotationEffect(.degrees(5))

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MoveMarkTheme.Colors.evidenceCard.opacity(0.95))
                .frame(width: 60, height: 92)
                .offset(x: 5, y: -4)
                .rotationEffect(.degrees(2.5))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MoveMarkTheme.Colors.paperSurface.opacity(isDocumentBright ? 0.98 : 0.9))
                .frame(width: 72, height: 108)
                .shadow(color: Color.black.opacity(0.14), radius: 8, y: 3)
                .overlay {
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(
                                isDocumentBright
                                    ? MoveMarkTheme.Colors.primary.opacity(0.85)
                                    : MoveMarkTheme.Colors.semanticWarning.opacity(0.75)
                            )
                            .frame(width: 36, height: 5)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(MoveMarkTheme.Colors.textOnLight.opacity(0.12))
                            .frame(width: 44, height: 4)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(MoveMarkTheme.Colors.textOnLight.opacity(0.08))
                            .frame(width: 40, height: 4)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(MoveMarkTheme.Colors.textOnLight.opacity(0.06))
                            .frame(height: 4)

                        Spacer(minLength: 0)

                        HStack(spacing: 4) {
                            Image(systemName: documentIcon)
                                .font(.system(size: 11, weight: .semibold))
                            Text("PDF")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(
                            isDocumentBright
                                ? MoveMarkTheme.Colors.primaryPressed
                                : MoveMarkTheme.Colors.textOnLight.opacity(0.55)
                        )
                    }
                    .padding(12)
                }
                .opacity(state == .processing ? 0.82 : 1)
                .animation(
                    reduceMotion || state != .processing
                        ? nil
                        : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: state
                )
        }
        .frame(width: 88, height: 116)
    }

    private var documentIcon: String {
        switch state {
        case .ready, .canMake: return "checkmark.seal.fill"
        case .processing: return "hourglass"
        case .failed: return "exclamationmark.triangle.fill"
        default: return "lock.fill"
        }
    }

    private func proofChip(_ label: String) -> some View {
        Text(label)
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
