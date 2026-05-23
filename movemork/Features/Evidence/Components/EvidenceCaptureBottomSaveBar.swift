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
        return "\(photoCount) photo\(photoCount == 1 ? "" : "s") ready to save"
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusColor)
                .animation(MMMotion.fastFade, value: didJustSave)
                .animation(MMMotion.fastFade, value: isUploading)

            MMButton(
                title: saveTitle,
                action: onSave,
                kind: .primary,
                size: .standard,
                isDisabled: photoCount == 0 || isUploading
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MoveMarkTheme.Colors.evidenceCard)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.cardStroke)
                .frame(height: 0.5)
        }
    }
}
