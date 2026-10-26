//
//  EvidenceCaptureBottomSaveBar.swift
//  movemork
//
//  Sticky bottom save bar: honest upload state + save CTA.
//

import SwiftUI

struct EvidenceCaptureBottomSaveBar: View {
    let photoCount: Int
    let tagCount: Int
    let condition: RoomRecord.ConditionRating
    let isUploading: Bool
    let didJustSave: Bool
    let moveOutMode: Bool
    let onSave: () -> Void

    private var statusLine: String {
        if isUploading { return "Saving proof…" }
        if didJustSave { return "Proof saved" }
        if photoCount == 0 { return "Add photos to continue" }
        return "\(photoCount) photo\(photoCount == 1 ? "" : "s") ready"
    }

    private var statusColor: Color {
        if photoCount == 0, !isUploading, !didJustSave {
            return MoveMarkTheme.Colors.semanticWarning.opacity(0.95)
        }
        if didJustSave { return MoveMarkTheme.Colors.semanticSuccess.opacity(0.95) }
        return MoveMarkTheme.Colors.textSecondary
    }

    private var saveTitle: String {
        if isUploading { return "Uploading…" }
        if didJustSave { return "Saved" }
        return "Save proof"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(statusLine)
                .font(MoveMarkTheme.Typography.footnoteEmphasis)
                .foregroundStyle(statusColor)
                .animation(MMMotion.fastFade, value: didJustSave)
                .animation(MMMotion.fastFade, value: isUploading)

            // The MoveMark action lime, as on the Vault, the room brief and the receipt.
            Button(action: onSave) {
                Text(saveTitle)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(RoomEvidenceHero.onLime)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(RoomEvidenceHero.lime, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(photoCount == 0 || isUploading)
            .opacity(photoCount == 0 || isUploading ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Solid, down through the home-indicator area, so the page scrolling underneath never shows.
        .background(MoveMarkTheme.Colors.appBackground.ignoresSafeArea(edges: .bottom))
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }
}
