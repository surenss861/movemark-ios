//
//  EvidenceCaptureMediaModule.swift
//  movemork
//
//  Proof media: capture actions + selected photo grid.
//

import SwiftUI
import PhotosUI

struct EvidenceCaptureMediaModule: View {
    @Binding var selectedItems: [PhotosPickerItem]
    var onOpenCamera: () -> Void

    let loadedImages: [UIImage]
    let isUploading: Bool
    let moveOutMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MMButton(
                title: "Take photos",
                action: onOpenCamera,
                kind: .primary,
                size: .standard,
                isDisabled: isUploading
            )

            PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                    Text("Choose from gallery")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                }
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: MoveMarkTheme.Spacing.buttonHeight)
                .background(MoveMarkTheme.Colors.fieldFill.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: MoveMarkTheme.Spacing.cornerRadius, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.72), lineWidth: 0.9)
                )
                .clipShape(RoundedRectangle(cornerRadius: MoveMarkTheme.Spacing.cornerRadius, style: .continuous))
            }
            .disabled(isUploading)

            VStack(alignment: .leading, spacing: 10) {
                Text("Selected photos")
                    .font(MoveMarkTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .padding(.leading, 2)

                ProofPhotoGridView(images: loadedImages, isUploading: isUploading)
                    .padding(14)
                    .background(MoveMarkTheme.Colors.evidenceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
