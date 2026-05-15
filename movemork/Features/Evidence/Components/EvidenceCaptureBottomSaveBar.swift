//
//  EvidenceCaptureBottomSaveBar.swift
//  movemork
//
//  Sticky bottom save bar: photo count, tags/condition, save CTA. Slim product chrome.
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

    private var tagSummary: String {
        tagCount == 0 ? "No tags" : "\(tagCount) tag\(tagCount == 1 ? "" : "s")"
    }

    private var primaryLine: String {
        if isUploading { return "Saving proof…" }
        if didJustSave { return "Proof saved" }
        return photoCount == 0
            ? "Add media to continue"
            : "\(photoCount) photo\(photoCount == 1 ? "" : "s") ready to save"
    }

    private var primaryLineColor: Color {
        if photoCount == 0, !isUploading, !didJustSave {
            return MoveMarkTheme.Colors.semanticWarning.opacity(0.95)
        }
        if didJustSave { return MoveMarkTheme.Colors.semanticSuccess.opacity(0.95) }
        return MoveMarkTheme.Colors.textPrimary
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryLine)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryLineColor)
                    .animation(MMMotion.fastFade, value: didJustSave)
                    .animation(MMMotion.fastFade, value: isUploading)

                Text("\(tagSummary) · \(condition.rawValue)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
            }

            Spacer(minLength: 0)

            Button(action: onSave) {
                Text(
                    MMNextBestActionMapper.evidenceSaveBarTitle(
                        photoCount: photoCount,
                        isUploading: isUploading,
                        didJustSave: didJustSave,
                        moveOutMode: moveOutMode
                    )
                )
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(photoCount == 0 ? MoveMarkTheme.Colors.textSecondary : MoveMarkTheme.Colors.textOnPrimary)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(
                    Capsule()
                        .fill(
                            photoCount == 0
                                ? MoveMarkTheme.Colors.mint.opacity(0.6)
                                : MoveMarkTheme.Colors.primary.opacity(isUploading ? 0.72 : 1.0)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(photoCount == 0 || isUploading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(MoveMarkTheme.Colors.panel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.panelStroke)
                .frame(height: 0.5)
        }
        .shadow(color: MoveMarkTheme.Colors.textPrimary.opacity(0.06), radius: 8, y: -2)
    }
}
