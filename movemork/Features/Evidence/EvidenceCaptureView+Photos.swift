//
//  EvidenceCaptureView+Photos.swift
//  movemork
//
//  Photo picker loading and downsampling.
//

import SwiftUI
import PhotosUI

extension EvidenceCaptureView {
    func loadSelectedItems(_ items: [PhotosPickerItem]) {
        Task { @MainActor in
            var images: [UIImage] = []

            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(downsample(image, maxDimension: 1200))
                }
            }

            loadedImages = images
        }
    }

    func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / max(size.width, size.height), 1.0)

        guard scale < 1.0 else { return image }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
