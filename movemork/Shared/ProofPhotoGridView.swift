//
//  ProofPhotoGridView.swift
//  movemork
//
//  Selected proof photos in a clean evidence grid.
//

import SwiftUI
import UIKit

struct ProofPhotoGridView: View {
    let images: [UIImage]
    var isUploading: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        Group {
            if images.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ProofPhotoGridCell(image: image, isUploading: isUploading)
                            .aspectRatio(1, contentMode: .fit)
                            .mmAppearRise(isVisible: true, delay: reduceMotion ? 0 : Double(index) * 0.03, offset: 4)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.72))

            Text("Add photos to create proof for this room.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(MoveMarkTheme.Colors.fieldFill.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProofPhotoGridCell: View {
    let image: UIImage
    let isUploading: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
                )

            if isUploading {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MoveMarkTheme.Colors.evidenceCard.opacity(0.45))
                ProgressView()
                    .tint(MoveMarkTheme.Colors.primary)
            }
        }
    }
}
