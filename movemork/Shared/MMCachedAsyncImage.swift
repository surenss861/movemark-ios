//
//  MMCachedAsyncImage.swift
//  movemork
//
//  Path-keyed disk image cache for signed-URL photos.
//
//  Supabase signed URLs mint a fresh token/expiry query string every time they're re-created for the
//  same underlying storage object (see `MoveMarkSignedURLCache`, which caches the *URL* in memory for
//  ~50 min but still mints a brand-new URL after that, or after a relaunch). `AsyncImage`/`URLCache` key
//  on the full URL, so every re-mint is a cache miss even though the bytes on disk are identical.
//
//  This view instead keys the on-disk cache by the stable storage *path* (e.g. "userId/propertyId/move-in/
//  roomId/file.jpg"), which never changes for a given object. On appear it checks disk first (instant, no
//  network) and only falls back to downloading `signedURL` on a miss, then writes the result back keyed by path.
//

import SwiftUI
import CryptoKit
import ImageIO

/// Mirrors `AsyncImagePhase` so call sites can swap `AsyncImage(url:)` for this with the same `{ phase in }` body.
enum MMCachedImagePhase {
    case empty
    case success(Image)
    case failure
}

/// On-disk cache of decoded photo bytes, keyed by a stable storage path (not by signed URL). Nonisolated:
/// reads, writes and decoding run off the main thread.
nonisolated enum MMImageDiskCache {
    private static let folder: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MMImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func fileURL(forKey key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent(hex, isDirectory: false).appendingPathExtension("img")
    }

    /// Reads cached bytes for `key` off the main thread. Returns `nil` on a cache miss.
    static func data(forKey key: String) -> Data? {
        try? Data(contentsOf: fileURL(forKey: key))
    }

    /// Writes bytes for `key`; best-effort (a failed write just means the next load re-downloads).
    static func store(_ data: Data, forKey key: String) {
        try? data.write(to: fileURL(forKey: key), options: .atomic)
    }

    /// Removes one cached entry (e.g. when a caller knows a given path's bytes changed — re-capture, replace).
    static func remove(forKey key: String) {
        try? FileManager.default.removeItem(at: fileURL(forKey: key))
    }

    /// Long side cap for display: the cards using this are at most screen-wide (≈1300 px on a 3x phone).
    static let maxDisplayPixels = 1600

    /// Decodes `data` now (not lazily at first draw on the main thread), downsampled to `maxDisplayPixels`
    /// and oriented. A 4096 px evidence photo becomes ~10 MB in memory instead of ~50 MB.
    static func displayImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDisplayPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

/// Drop-in replacement for `AsyncImage(url:content:)` that checks a path-keyed disk cache before hitting
/// the network, so re-minted signed URLs for the same object still resolve instantly from disk.
///
/// - Parameters:
///   - path: Stable storage path (e.g. `evidence_files.file_path`). This is the cache key — pass whatever
///     the caller already has instead of parsing it back out of a signed URL.
///   - signedURL: The current signed URL for `path`, or `nil` while it's still being resolved. Only
///     consulted on a disk-cache miss.
struct MMCachedAsyncImage<Content: View>: View {
    let path: String?
    let signedURL: URL?
    @ViewBuilder var content: (MMCachedImagePhase) -> Content

    @State private var image: UIImage?
    @State private var didFail = false

    init(
        path: String?,
        signedURL: URL?,
        @ViewBuilder content: @escaping (MMCachedImagePhase) -> Content
    ) {
        self.path = path
        self.signedURL = signedURL
        self.content = content
    }

    private var cacheKey: String? {
        if let path, !path.isEmpty { return path }
        return signedURL?.absoluteString
    }

    /// Re-runs the load whenever the identity of what we'd load changes (key becomes known, or the signed
    /// URL arrives after a disk-cache miss that had nothing to download yet).
    private var taskId: String {
        "\(cacheKey ?? "")|\(signedURL?.absoluteString ?? "")"
    }

    var body: some View {
        content(phase)
            .task(id: taskId) {
                await load()
            }
    }

    private var phase: MMCachedImagePhase {
        if let image {
            return .success(Image(uiImage: image))
        }
        if didFail {
            return .failure
        }
        return .empty
    }

    private func load() async {
        guard let cacheKey else { return }

        // Disk read and decode off the main thread.
        let cachedImage = await Task.detached(priority: .userInitiated) {
            MMImageDiskCache.data(forKey: cacheKey).flatMap(MMImageDiskCache.displayImage(from:))
        }.value
        if let cachedImage {
            image = cachedImage
            didFail = false
            return
        }

        guard let signedURL else { return }
        // Keyed only by a one-off signed URL, the bytes would never be read again: don't fill the disk with them.
        let persist = path.map { !$0.isEmpty } ?? false

        do {
            let (data, _) = try await URLSession.shared.data(from: signedURL)
            let downloaded = await Task.detached(priority: .userInitiated) {
                let decoded = MMImageDiskCache.displayImage(from: data)
                if decoded != nil, persist { MMImageDiskCache.store(data, forKey: cacheKey) }
                return decoded
            }.value
            guard let downloaded else {
                didFail = true
                return
            }
            image = downloaded
            didFail = false
        } catch {
            didFail = true
        }
    }
}
