//
//  EvidenceCaptureMediaModule.swift
//  movemork
//
//  Proof media: quiet card, camera + library, ready-for-proof strip.
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
        VStack(alignment: .leading, spacing: 12) {
            Text(moveOutMode ? "Move-out media" : "Proof media")
                .font(MoveMarkTheme.Typography.caption)
                .tracking(1.0)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            MMCard(tone: .quiet, padding: 16, spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Button {
                            onOpenCamera()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Take photo")
                                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                            }
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(MoveMarkTheme.Colors.fieldFill.opacity(0.82))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.72), lineWidth: 0.9)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploading)

                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(loadedImages.isEmpty ? "Choose photos" : "\(loadedImages.count) selected")
                                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                            }
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(MoveMarkTheme.Colors.fieldFill.opacity(0.82))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.72), lineWidth: 0.9)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .disabled(isUploading)
                    }

                    if !loadedImages.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("\(loadedImages.count) photo\(loadedImages.count == 1 ? "" : "s") ready")
                                    .font(MoveMarkTheme.Typography.footnote)
                                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.86))

                                Spacer()

                                Text("Ready for proof")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                    .padding(.horizontal, 10)
                                    .frame(height: 24)
                                    .background(Color.white.opacity(0.045))
                                    .clipShape(Capsule())
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                PhotoStripView(images: loadedImages)
                            }
                            .padding(10)
                            .background(MoveMarkTheme.Colors.fieldFill.opacity(0.62))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
        }
    }
}
