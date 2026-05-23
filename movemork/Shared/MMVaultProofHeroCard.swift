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
    var roomName: String? = nil
    var photoCount: Int = 0
    var issueCount: Int = 0
    let primaryTitle: String
    let onPrimary: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double { min(1, max(0, progress)) }
    private var hasProof: Bool { clampedProgress > 0 || previewURL != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasProof, previewURL != nil {
                ProofArtifactCard(
                    model: ProofArtifactModel(
                        phaseEyebrow: "Room Proof",
                        phaseLabel: phaseLabel,
                        roomName: roomName ?? propertyName,
                        photoCount: max(photoCount, 1),
                        issueCount: issueCount,
                        verifiedLabel: progressLine,
                        savedLabel: "Saved to vault",
                        statusLabel: statusLabel,
                        statusTone: hasProof ? .success : .warning
                    ),
                    photoHeight: 140,
                    cornerRadius: 20,
                    imageURL: previewURL
                )
                .padding(.bottom, 14)
            } else {
                ProofTaskCard(
                    title: roomName.map { "Start with \($0)" } ?? "Start move-in proof",
                    reason: nextLine,
                    action: onPrimary,
                    statusLabel: statusLabel,
                    statusTone: hasProof ? .success : .warning,
                    showChevron: false
                )
                .padding(.bottom, 12)
                MMButton(
                    title: primaryTitle,
                    action: {
                        MMHaptics.soft()
                        onPrimary()
                    },
                    kind: .primary,
                    size: .standard
                )
                .padding(.bottom, 14)
            }

            if let location, !location.isEmpty {
                Text(location)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
            if hasProof {
                Text(nextLine)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .padding(.top, 4)
                progressBar
                    .padding(.top, 10)
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
    }

    private var statusLabel: String {
        if clampedProgress >= 1 { return "All rooms ready" }
        if hasProof { return "In progress" }
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
