//
//  ProofSavedReceiptView.swift
//  movemork
//
//  Strongest proof moment — saved artifact, calm success, clear next action.
//

import SwiftUI

struct ProofSavedReceiptModel {
    var roomName: String
    var phaseLabel: String = "Move-in"
    var photoCount: Int
    var issueCount: Int = 0
    var timestampLabel: String
    var headerSubtitle: String
    var documentedLabel: String = "Room now documented"
    var partialMessage: String?
    var primaryActionLabel: String
    var imageName: String?
    var imageURL: URL?
}

struct ProofSavedReceiptView: View {
    let model: ProofSavedReceiptModel
    let onPrimary: () -> Void
    let onViewVault: () -> Void
    var onAddMorePhotos: (() -> Void)?
    var onRetryUpload: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var checkScale: CGFloat = 0.72

    private var hasPartialUpload: Bool { model.partialMessage != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            receiptHeader
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 8)

            ProofArtifactCard(
                model: ProofArtifactModel(
                    phaseEyebrow: "Room Proof",
                    phaseLabel: model.phaseLabel,
                    roomName: model.roomName,
                    photoCount: max(model.photoCount, 1),
                    issueCount: model.issueCount,
                    verifiedLabel: verifiedLabel,
                    savedLabel: "Saved to vault",
                    statusLabel: "Saved",
                    statusTone: hasPartialUpload ? .warning : .success
                ),
                photoHeight: 220,
                cornerRadius: 20,
                imageName: model.imageName,
                imageURL: model.imageURL,
                tagsVisible: false
            )
            .padding(.top, 18)
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 10)

            if let partialMessage = model.partialMessage {
                Text("\(partialMessage). You can retry the rest or continue with saved proof.")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MoveMarkTheme.Colors.semanticWarning.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 12)
            }

            VStack(spacing: 10) {
                MMButton(
                    title: model.primaryActionLabel,
                    action: onPrimary,
                    kind: .primary,
                    size: .auth
                )
                MMButton(
                    title: "View proof vault",
                    action: onViewVault,
                    kind: .secondary,
                    size: .standard
                )
                if let onAddMorePhotos {
                    MMButton(
                        title: "Add more photos",
                        action: onAddMorePhotos,
                        kind: .secondary,
                        size: .standard
                    )
                }
                if hasPartialUpload, let onRetryUpload {
                    MMButton(
                        title: "Retry upload",
                        action: onRetryUpload,
                        kind: .secondary,
                        size: .standard
                    )
                }
            }
            .padding(.top, 20)
            .opacity(visible ? 1 : 0)
        }
        .onAppear { playEntrance() }
    }

    private var verifiedLabel: String {
        if let partialMessage = model.partialMessage {
            return "\(partialMessage) · \(model.timestampLabel)"
        }
        return model.timestampLabel
    }

    private var receiptHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.primary)
                .scaleEffect(checkScale)
            VStack(alignment: .leading, spacing: 4) {
                Text("Saved to your vault")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                Text(model.headerSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                if !model.documentedLabel.isEmpty {
                    Text(model.documentedLabel)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
            }
        }
    }

    private func playEntrance() {
        guard !reduceMotion else {
            visible = true
            checkScale = 1
            return
        }
        withAnimation(.easeOut(duration: 0.42)) {
            visible = true
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72).delay(0.09)) {
            checkScale = 1
        }
    }
}
