//
//  MMEvidenceImport.swift
//  movemork
//
//  MoveMark — the one place evidence images are prepared for upload. Every evidence entry
//  point (camera, room library picks, append sheet, maintenance log, maintenance detail) uses it.
//
//  Three representations, kept strictly apart:
//  - SOURCE: the file exactly as the device produced it (library file bytes, or the camera's
//    encoded capture file from `AVCapturePhoto.fileDataRepresentation()`). Never decoded and
//    re-encoded, resized, cropped, enhanced or converted. Keeps all of its metadata, GPS included;
//    stored privately and never served by normal APIs.
//  - WORKING DERIVATIVE: a JPEG made from the source for the UI, downloads and PDFs. Orientation
//    applied, long side ≤ 4096 px and never upscaled, quality 0.90, capture date kept, GPS removed.
//  - THUMBNAIL: ≤ 320 px JPEG for grids, no metadata.
//
//  Everything goes through ImageIO, which works in pixels: nothing here depends on the device's
//  screen scale (UIKit renderers multiplied sizes by it, which upscaled evidence on 3x phones).
//

import CryptoKit
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Evidence source formats the server accepts as immutable sources. Anything else (e.g. DNG/ProRAW,
/// GIF, WebP, TIFF) is refused with a clear error rather than silently transcoded.
enum MMEvidenceCaptureSource: String, Sendable {
    case camera
    case library
}

struct MMEvidenceSource: Sendable, Equatable {
    /// The file's bytes, exactly as received from the platform.
    let data: Data
    let mimeType: String
    let fileExtension: String
    /// Stored pixel dimensions of the file (before orientation is applied).
    let pixelWidth: Int
    let pixelHeight: Int
    let sha256Hex: String
    /// EXIF `DateTimeOriginal` (with `OffsetTimeOriginal` when present): declared by the file, not
    /// verified. MoveMark's own receipt time is recorded separately by the server.
    let capturedAt: Date?
    let captureSource: MMEvidenceCaptureSource
}

enum MMEvidenceImportError: LocalizedError, Equatable {
    case unreadable
    case unsupportedFormat(String)
    case tooLarge(bytes: Int)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "This photo couldn’t be read. Try another one."
        case .unsupportedFormat(let type):
            return "This photo format (\(type)) isn’t supported yet. Use a JPEG, HEIC or PNG photo."
        case .tooLarge:
            return "This photo is larger than 25 MB, so it can’t be stored as original evidence."
        }
    }
}

enum MMEvidenceImport {
    /// Server limit for immutable sources (`SOURCE` in the API). Sources are never shrunk to fit.
    static let maxSourceBytes = 25 * 1024 * 1024
    /// Server limit for the working derivative (`PHOTO` in the API).
    static let maxDerivativeBytes = 15 * 1024 * 1024
    static let derivativeMaxPixels = 4096
    static let derivativeQuality: CGFloat = 0.90
    static let thumbnailMaxPixels = 320
    static let thumbnailQuality: CGFloat = 0.70

    private static let accepted: [String: (mime: String, ext: String)] = [
        UTType.jpeg.identifier: ("image/jpeg", "jpg"),
        UTType.heic.identifier: ("image/heic", "heic"),
        UTType.heif.identifier: ("image/heif", "heif"),
        UTType.png.identifier: ("image/png", "png"),
    ]

    // MARK: Source

    /// Wraps the platform's file bytes as source evidence. Reads metadata only; the bytes are untouched.
    static func source(from data: Data, captureSource: MMEvidenceCaptureSource) throws -> MMEvidenceSource {
        guard let image = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(image) as String?,
              CGImageSourceGetCount(image) > 0
        else { throw MMEvidenceImportError.unreadable }
        guard let format = accepted[type] else {
            throw MMEvidenceImportError.unsupportedFormat(UTType(type)?.preferredFilenameExtension?.uppercased() ?? type)
        }
        guard data.count <= maxSourceBytes else { throw MMEvidenceImportError.tooLarge(bytes: data.count) }
        let props = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any] ?? [:]
        guard let width = props[kCGImagePropertyPixelWidth] as? Int, let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { throw MMEvidenceImportError.unreadable }
        return MMEvidenceSource(
            data: data,
            mimeType: format.mime,
            fileExtension: format.ext,
            pixelWidth: width,
            pixelHeight: height,
            sha256Hex: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            capturedAt: captureDate(props),
            captureSource: captureSource
        )
    }

    /// EXIF `DateTimeOriginal` (+ `OffsetTimeOriginal`). Without an offset the photo's local time is
    /// read in the device's time zone — the same assumption Photos makes.
    static func captureDate(_ props: [CFString: Any]) -> Date? {
        guard let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
            if let date = formatter.date(from: original + offset) { return date }
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter.date(from: original)
    }

    // MARK: Derived images

    /// Working derivative: JPEG, orientation applied, long side ≤ 4096 and never above the source's,
    /// quality 0.90, capture date kept, GPS and other metadata dropped. If it exceeds the server's
    /// derivative limit it is reduced deterministically (quality first, then size) — the source is
    /// never touched to make a derivative fit.
    static func derivative(from source: MMEvidenceSource, maxBytes: Int = maxDerivativeBytes) -> Data? {
        let longSide = max(source.pixelWidth, source.pixelHeight)
        var maxPixels = min(derivativeMaxPixels, longSide)
        let qualities: [CGFloat] = [derivativeQuality, 0.85, 0.80, 0.75, 0.70]
        while maxPixels >= 256 {
            for quality in qualities {
                guard let jpeg = render(source.data, maxPixels: maxPixels, quality: quality, keepCaptureDate: true) else { return nil }
                if jpeg.count <= maxBytes { return jpeg }
            }
            maxPixels = Int(Double(maxPixels) * 0.85)
        }
        return nil
    }

    /// Thumbnail: JPEG, orientation applied, long side ≤ 320 (never above the source's), no metadata.
    static func thumbnail(from source: MMEvidenceSource) -> Data? {
        render(source.data, maxPixels: min(thumbnailMaxPixels, max(source.pixelWidth, source.pixelHeight)),
               quality: thumbnailQuality, keepCaptureDate: false)
    }

    /// On-screen preview of a pending photo (display only; never uploaded).
    static func preview(from source: MMEvidenceSource, maxPixels: Int = 1200) -> UIImage? {
        guard let image = CGImageSourceCreateWithData(source.data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(image, 0, thumbnailOptions(maxPixels: min(maxPixels, max(source.pixelWidth, source.pixelHeight))))
        else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func thumbnailOptions(maxPixels: Int) -> CFDictionary {
        [
            kCGImageSourceCreateThumbnailFromImageAlways: true,  // from the full image, never an embedded preview
            kCGImageSourceCreateThumbnailWithTransform: true,    // apply EXIF orientation to the pixels
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,      // pixels, not points
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary
    }

    private static func render(_ data: Data, maxPixels: Int, quality: CGFloat, keepCaptureDate: Bool) -> Data? {
        guard let image = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(image, 0, thumbnailOptions(maxPixels: maxPixels))
        else { return nil }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        // Only what we choose to carry: no GPS, no maker notes, no TIFF/IPTC from the source.
        var props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyOrientation: 1,  // pixels are already upright
        ]
        if keepCaptureDate,
           let sourceProps = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
           let exif = sourceProps[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            var kept: [CFString: Any] = [:]
            for key in [kCGImagePropertyExifDateTimeOriginal, kCGImagePropertyExifOffsetTimeOriginal] {
                if let value = exif[key] { kept[key] = value }
            }
            if !kept.isEmpty { props[kCGImagePropertyExifDictionary] = kept }
        }
        CGImageDestinationAddImage(destination, cg, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }
}

#if DEBUG
/// DEBUG builds only: an append-only record of the SHA-256 of bytes exactly as the platform handed them
/// over (camera `fileDataRepresentation()`, picker file data), so a device test can prove the hash chain
/// platform bytes → uploaded source → stored object. Written to Documents/evidence-audit.log.
enum MMEvidenceAuditLog {
    static func record(_ origin: String, _ data: Data) {
        let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let type = CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceGetType($0) as String? } ?? "?"
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(origin) bytes=\(data.count) type=\(type) sha256=\(hex)\n"
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let file = dir.appendingPathComponent("evidence-audit.log")
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile(); handle.write(Data(line.utf8)); try? handle.close()
        } else {
            try? Data(line.utf8).write(to: file)
        }
    }
}
#endif
