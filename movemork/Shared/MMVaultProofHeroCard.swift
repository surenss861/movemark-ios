//
//  MMVaultProofHeroCard.swift
//  movemork
//

import SwiftUI

struct MMVaultProofHeroCard: View {
    let propertyName: String
    var location: String? = nil
    var phaseLabel: String = "Move-in proof"
    let progressLine: String
    let nextLine: String
    let progress: Double
    var previewURL: URL? = nil
    let primaryTitle: String
    let onPrimary: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double { min(1, max(0, progress)) }
    private var hasProof: Bool { clampedProgress > 0 }

    var body: some View {
        ProofCaseCard(
            cornerRadius: 22,
            header: ProofCaseHeader(
                eyebrow: phaseLabel,
                statusLabel: statusLabel,
                statusTone: hasProof ? .success : .warning,
                accentRail: hasProof ? .saved : .needsProof
            ),
            contentPadding: 16
        ) {
            ProofPhotoPane(
                size: .medium,
                imageURL: previewURL,
                roomName: propertyName,
                phaseLabel: progressLine
            )
            .frame(maxWidth: .infinity)
            .frame(height: hasProof || previewURL != nil ? 120 : 96)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.bottom, 14)

            if let location, !location.isEmpty {
                Text(location)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
            Text(nextLine)
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .padding(.top, 4)

            progressBar
                .padding(.top, 12)

            MMButton(
                title: primaryTitle,
                action: {
                    MMHaptics.soft()
                    onPrimary()
                },
                kind: .primary,
                size: .standard
            )
            .padding(.top, 14)
        }
    }

    private var statusLabel: String {
        if clampedProgress >= 1 { return "All rooms ready" }
        if hasProof { return progressLine }
        return "Needs photos"
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.85))
                    .frame(height: 4)
                Capsule()
                    .fill(MoveMarkTheme.Colors.primary.opacity(clampedProgress > 0 ? 0.9 : 0.35))
                    .frame(width: max(4, geo.size.width * clampedProgress), height: 4)
                    .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clampedProgress)
            }
        }
        .frame(height: 4)
    }
}
