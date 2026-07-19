//
//  MMImageThumbnail.swift
//  movemork
//
//  Small (~320px) JPEG generation for grid/list thumbnails, uploaded alongside full-size captures.
//

import UIKit

enum MMImageThumbnail {
    /// Generates a small JPEG from full-size image data, matching the app's existing full-size
    /// downscale approach (`EvidenceCaptureView.downsample`, `MaintenanceLogView`'s equivalent) at a
    /// smaller target dimension so photo grids don't have to load full-size images.
    static func make(from data: Data, maxDimension: CGFloat = 320, compressionQuality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }

    /// Derives a sibling thumbnail storage path next to `path` (e.g. `".../file.jpg"` -> `".../file_thumb.jpg"`),
    /// so the pairing is obvious to anyone reading storage directly.
    static func thumbnailPath(for path: String) -> String {
        let ns = path as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        return ext.isEmpty ? "\(base)_thumb" : "\(base)_thumb.\(ext)"
    }
}
