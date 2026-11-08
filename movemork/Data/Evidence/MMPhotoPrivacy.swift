//
//  MMPhotoPrivacy.swift
//  movemork
//
//  @file Option B (owner decision 2026-11-08): for accounts whose declared age range is 13 to 17, every photo and
//        image document is stripped of location (GPS) and other identifying metadata (camera make/model/software,
//        serial numbers, owner, lens, maker notes, IPTC and XMP) on the device, BEFORE it is saved to the pending
//        queue or uploaded. Only the capture date (+ offset) and orientation are kept, so evidence still says when.
//        Adults keep today's behaviour: the source file exactly as the device produced it. The server enforces the
//        teen rule independently (API finalize checks the stored bytes; migration 1056 refuses unchecked rows).
//
//        Also the off-main pipeline for evidence and document image work (Sentry audit 2026-11-08: resize,
//        re-encode, hashing and decoding ran on the main actor during rapid capture and imports).
//  @domain evidence
//  @status stable
//

import CryptoKit
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// The account's photo rule, from the server's `age_category` ('teen' or 'adult').
nonisolated enum MMPhotoPrivacy: String, Sendable {
    /// Today's behaviour: sources are kept byte-for-byte.
    case standard
    /// 13 to 17: location and identifying metadata removed before anything is stored.
    case teen
}

/// Where the import pipeline reads the current rule. Set by ``SessionManager`` from the legal status and kept per
/// account on the device so an offline launch still knows it. Not an authority: the server enforces.
nonisolated final class MMPhotoPrivacyPolicy: @unchecked Sendable {
    static let shared = MMPhotoPrivacyPolicy()

    private let lock = NSLock()
    private var value: MMPhotoPrivacy = .standard

    var current: MMPhotoPrivacy {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    private static func key(_ userId: UUID) -> String { "MoveMarkPhotoPrivacy.\(userId.uuidString.lowercased())" }

    /// From the server's `age_category`. `nil` (no declaration yet) keeps whatever this account last had.
    func apply(serverCategory: String?, userId: UUID?) {
        guard let userId else { return }
        if let serverCategory {
            let next: MMPhotoPrivacy = serverCategory == "teen" ? .teen : .standard
            UserDefaults.standard.set(next.rawValue, forKey: Self.key(userId))
            set(next)
        } else {
            restore(userId: userId)
        }
    }

    /// At sign-in, before the status call answers (or when it can't).
    func restore(userId: UUID) {
        set(MMPhotoPrivacy(rawValue: UserDefaults.standard.string(forKey: Self.key(userId)) ?? "") ?? .standard)
    }

    func reset() { set(.standard) }

    func set(_ next: MMPhotoPrivacy) {
        lock.lock(); value = next; lock.unlock()
    }
}

/// `nonisolated`: the target's default isolation is MainActor, and an extension doesn't inherit the enum's
/// `nonisolated`. Without it these helpers ran on the main actor even when marked `@concurrent` (Sentry App Hang audit;
/// caught by the off-main check below during the RC3 test run).
nonisolated extension MMEvidenceImport {
    // MARK: Teen stripping

    /// The file with only capture date (+ offset) and orientation left. JPEG and PNG keep their format and pixels
    /// (lossless metadata copy); HEIC/HEIF become a full-resolution JPEG, because teen sources must be a format the
    /// server can inspect. A file that is already clean comes back unchanged, so this is idempotent and stable.
    static func teenSafe(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?, CGImageSourceGetCount(source) > 0
        else { throw MMEvidenceImportError.unreadable }
        let isJPEGOrPNG = type == UTType.jpeg.identifier || type == UTType.png.identifier
        if isJPEGOrPNG, carriesNoIdentifyingMetadata(data, allowCaptureDate: true) { return data }

        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if type == UTType.jpeg.identifier {
            // Lossless: the compressed image data is copied; only the metadata we pass is written. Orientation goes in as a
            // metadata tag (ImageIO refuses kCGImageDestinationOrientation together with kCGImageDestinationMetadata).
            let out = NSMutableData()
            if let destination = CGImageDestinationCreateWithData(out, type as CFString, 1, nil) {
                let metadata = CGImageMetadataCreateMutable()
                for key in [kCGImagePropertyExifDateTimeOriginal, kCGImagePropertyExifOffsetTimeOriginal] {
                    if let value = exif[key] {
                        CGImageMetadataSetValueMatchingImageProperty(metadata, kCGImagePropertyExifDictionary, key, value as CFTypeRef)
                    }
                }
                CGImageMetadataSetValueMatchingImageProperty(metadata, kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFOrientation,
                                                             orientation as CFNumber)
                let options: [CFString: Any] = [
                    kCGImageDestinationMetadata: metadata,
                    kCGImageDestinationMergeMetadata: false,
                    kCGImageMetadataShouldExcludeGPS: true,
                ]
                if CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, nil),
                   carriesNoIdentifyingMetadata(out as Data, allowCaptureDate: true) {
                    return out as Data
                }
            }
        } else if type == UTType.png.identifier {
            // PNG compression is lossless, so re-encoding keeps every pixel; a metadata copy would keep eXIf (GPS) here.
            var kept: [CFString: Any] = [:]
            for key in [kCGImagePropertyExifDateTimeOriginal, kCGImagePropertyExifOffsetTimeOriginal] {
                if let value = exif[key] { kept[key] = value }
            }
            let out = NSMutableData()
            if let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
               let destination = CGImageDestinationCreateWithData(out, type as CFString, 1, nil) {
                var props: [CFString: Any] = [kCGImagePropertyOrientation: orientation]
                if !kept.isEmpty { props[kCGImagePropertyExifDictionary] = kept }
                CGImageDestinationAddImage(destination, image, props as CFDictionary)
                if CGImageDestinationFinalize(destination), carriesNoIdentifyingMetadata(out as Data, allowCaptureDate: true) {
                    return out as Data
                }
            }
        }
        // HEIC/HEIF, or a JPEG/PNG ImageIO couldn't copy cleanly: the full image as JPEG, orientation applied.
        let longSide = max(props[kCGImagePropertyPixelWidth] as? Int ?? 0, props[kCGImagePropertyPixelHeight] as? Int ?? 0)
        guard longSide > 0, let jpeg = renderFullResolutionJPEG(data, longSide: longSide),
              carriesNoIdentifyingMetadata(jpeg, allowCaptureDate: true)
        else { throw MMEvidenceImportError.unreadable }
        return jpeg
    }

    // MARK: Off the main actor

    /// What an evidence upload sends: the source (stripped again for a teen account if it was queued before the
    /// rule was known), the working derivative and the thumbnail. CPU only, never on the main actor.
    @concurrent
    static func prepareForUpload(_ source: MMEvidenceSource, privacy: MMPhotoPrivacy) async throws
        -> (source: MMEvidenceSource, derivative: Data, thumbnail: Data?) {
        assertOffMain()
        var source = source
        if privacy == .teen, !(source.mimeType == "image/jpeg" || source.mimeType == "image/png")
            || !carriesNoIdentifyingMetadata(source.data, allowCaptureDate: true) {
            source = try MMEvidenceImport.source(from: source.data, captureSource: source.captureSource, privacy: .teen)
        }
        guard let derivative = derivative(from: source) else { throw MMEvidenceImportError.unreadable }
        return (source, derivative, thumbnail(from: source))
    }

    /// `source(from:captureSource:)` off the main actor, with the account's rule applied.
    @concurrent
    static func sourceOffMain(from data: Data, captureSource: MMEvidenceCaptureSource,
                              privacy: MMPhotoPrivacy = MMPhotoPrivacyPolicy.shared.current) async throws -> MMEvidenceSource {
        assertOffMain()
        return try source(from: data, captureSource: captureSource, privacy: privacy)
    }

    /// A library pick as evidence plus its display preview, off the main actor.
    @concurrent
    static func librarySelectionItem(_ data: Data, privacy: MMPhotoPrivacy = MMPhotoPrivacyPolicy.shared.current) async throws
        -> (source: MMEvidenceSource, preview: UIImage) {
        assertOffMain()
        let source = try source(from: data, captureSource: .library, privacy: privacy)
        guard let preview = preview(from: source) else { throw MMEvidenceImportError.unreadable }
        return (source, preview)
    }

    /// A photo-library pick as a vault document: JPEG and PNG keep their bytes (stripped first for a teen account),
    /// HEIC becomes the derivative JPEG; plus the thumbnail. Off the main actor.
    @concurrent
    static func documentImage(_ data: Data, privacy: MMPhotoPrivacy = MMPhotoPrivacyPolicy.shared.current) async throws
        -> (bytes: Data, fileExtension: String, thumbnail: Data?) {
        assertOffMain()
        let image = try source(from: data, captureSource: .library, privacy: privacy)
        let keepsBytes = image.mimeType == "image/jpeg" || image.mimeType == "image/png"
        guard let bytes = keepsBytes ? image.data : derivative(from: image) else { throw MMEvidenceImportError.unreadable }
        return (bytes, keepsBytes ? image.fileExtension : "jpg", thumbnail(from: image))
    }

    /// A file picked in Files as a vault document: read, and for a teen account a JPEG/PNG is stripped. PDFs are
    /// unchanged (the server checks a teen's PDF and refuses one carrying photo location). Off the main actor.
    @concurrent
    static func documentFile(at url: URL, privacy: MMPhotoPrivacy = MMPhotoPrivacyPolicy.shared.current) async throws -> Data {
        assertOffMain()
        let data = try Data(contentsOf: url)
        guard privacy == .teen, VaultDocumentPreviewFile.isJPEGOrPNG(data) else { return data }
        return try teenSafe(data)
    }

    /// The Quick Look copy of a stored document, off the main actor.
    @concurrent
    static func previewFileContents(_ data: Data) async throws -> Data {
        assertOffMain()
        return try VaultDocumentPreviewFile.contents(for: data)
    }

    /// Image work found on the main thread (it shouldn't happen: these helpers are `nonisolated @concurrent`). Counted
    /// and logged, never trapped, in every build; the unit tests assert the count stays at zero.
    static func assertOffMain() {
        guard Thread.isMainThread else { return }
        MMOffMainCheck.shared.recordViolation()
    }

    /// Full-size JPEG, orientation applied, capture date kept, nothing else.
    private static func renderFullResolutionJPEG(_ data: Data, longSide: Int) -> Data? {
        renderJPEG(data, maxPixels: longSide, quality: 0.95, keepCaptureDate: true)
    }
}

/// What the document preview writes to disk for Quick Look.
nonisolated enum VaultDocumentPreviewFile {
    struct UncleanableImage: LocalizedError {
        var errorDescription: String? { "This image couldn’t be prepared for viewing." }
    }

    /// JPEG and PNG come back without metadata; PDFs and anything else unchanged (they are the renter's own files and
    /// MoveMark doesn't rewrite them).
    static func contents(for data: Data) throws -> Data {
        guard isJPEGOrPNG(data) else { return data }
        guard let copy = MMEvidenceImport.sharedCopy(of: data) else { throw UncleanableImage() }
        return copy
    }

    static func isJPEGOrPNG(_ data: Data) -> Bool {
        let bytes = [UInt8](data.prefix(8))
        if bytes.count >= 3, bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF { return true }
        return bytes == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    }
}

/// Counts image work that landed on the main thread. Non-fatal by design (an earlier `dispatchPrecondition` crashed test
/// runs); the tests read `violations`.
nonisolated final class MMOffMainCheck: @unchecked Sendable {
    static let shared = MMOffMainCheck()
    private let lock = NSLock()
    private var count = 0

    var violations: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    func recordViolation() {
        lock.lock(); count += 1; lock.unlock()
        #if DEBUG
        print("[evidence] image work ran on the main thread")
        #endif
    }
}
