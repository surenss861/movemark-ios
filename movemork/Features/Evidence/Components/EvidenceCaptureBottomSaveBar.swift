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
                    didJustSave
                        ? "Saved"
                        : (isUploading
                            ? "Saving…"
                            : (moveOutMode ? "Save move-out" : "Save proof"))
                )
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white.opacity(photoCount == 0 ? 0.72 : 0.98))
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(
                    Capsule()
                        .fill(
                            photoCount == 0
                                ? Color.white.opacity(0.10)
                                : MoveMarkTheme.Colors.primary.opacity(isUploading ? 0.72 : 0.90)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(photoCount == 0 || isUploading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            ZStack {
                MoveMarkTheme.Colors.surfaceInset.opacity(0.88)
                MoveMarkTheme.Colors.background.opacity(0.55)
            }
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 0.6)
        }
        .shadow(color: .black.opacity(0.35), radius: 14, y: -4)
    }
}
