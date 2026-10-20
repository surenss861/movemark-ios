//
//  MMEvidenceImage.swift
//  movemork
//
//  @file Canonical evidence image pipeline (Nuke): path-keyed memory + disk cache, display-size
//        decoding, aspect-fill crop that can never letterbox, quiet fade-in, prefetch
//  @domain design-system
//  @status wip
//  @see [[VISUAL_STANDARD]] — user photos are the visual material
//  @see [[MMCachedAsyncImage.swift]] — older path cache, still used by screens not yet redesigned
//

import SwiftUI
import Nuke
import NukeUI

enum MMEvidenceImages {
    /// One pipeline for evidence photos. Disk cache keyed by storage path (see `request`), so a
    /// re-minted signed URL is never a cache miss.
    static let pipeline: ImagePipeline = {
        var config = ImagePipeline.Configuration.withDataCache(name: "com.movemark.evidence", sizeLimit: 400 * 1024 * 1024)
        config.dataCachePolicy = .storeOriginalData
        config.isProgressiveDecodingEnabled = false
        return ImagePipeline(configuration: config)
    }()

    /// Placeholder URL for cache-only lookups: the stable path is the identity, not the URL.
    static func cacheURL(for path: String) -> URL {
        URL(string: "mm-evidence://cache/\(path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path)")!
    }

    static func request(path: String, url: URL, size: CGSize?) -> ImageRequest {
        var processors: [any ImageProcessing] = []
        if let size, size.width > 0, size.height > 0 {
            // Decode at display size (points × screen scale), filled and cropped to the frame.
            processors.append(ImageProcessors.Resize(size: size, unit: .points, contentMode: .aspectFill, crop: true))
        }
        return ImageRequest(url: url, processors: processors, userInfo: [.imageIdKey: path])
    }

    /// Whether the original bytes for `path` are already on disk (no signing call needed).
    static func hasCachedData(path: String) -> Bool {
        pipeline.cache.containsData(for: request(path: path, url: cacheURL(for: path), size: nil))
    }

    /// Warm the cache for photos the user is likely to open next (e.g. a room's hero from Proof).
    static func prefetch(paths: [String], resolve: @escaping (String) async -> URL?) {
        Task {
            var requests: [ImageRequest] = []
            for path in paths where !hasCachedData(path: path) {
                if let url = await resolve(path) { requests.append(request(path: path, url: url, size: nil)) }
            }
            guard !requests.isEmpty else { return }
            prefetcher.startPrefetching(with: requests)
        }
    }

    private static let prefetcher = ImagePrefetcher(pipeline: pipeline, destination: .diskCache)
}

/// Snapshot tests and the QA gallery can supply images synchronously so renders are deterministic.
private struct MMEvidenceImageOverrideKey: EnvironmentKey {
    static let defaultValue: ((String) -> UIImage?)? = nil
}

extension EnvironmentValues {
    var mmEvidenceImageOverride: ((String) -> UIImage?)? {
        get { self[MMEvidenceImageOverrideKey.self] }
        set { self[MMEvidenceImageOverrideKey.self] = newValue }
    }
}

/// An evidence photo that always fills its frame. Give it a fixed frame from outside; it never
/// changes its own size, so a fill-cropped photo can't widen a layout or show bars.
struct MMEvidenceImage: View {
    let path: String
    /// Mints a signed URL for `path` (only called on a cache miss).
    let resolve: (String) async -> URL?
    /// Display size in points, for decoding. Nil decodes at full size (heroes, viewer).
    var size: CGSize? = nil
    var placeholder: Color = MoveMarkTheme.Light.fill
    /// Whole photo visible (viewer). Default fills and crops (cards, heroes).
    var fit: Bool = false

    @Environment(\.mmEvidenceImageOverride) private var override
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var url: URL?
    @State private var failed = false

    var body: some View {
        Color.clear
            .overlay {
                if let image = override?(path) {
                    SwiftUI.Image(uiImage: image).resizable().aspectRatio(contentMode: fit ? .fit : .fill)
                } else if let url {
                    LazyImage(request: MMEvidenceImages.request(path: path, url: url, size: size)) { state in
                        if let container = state.imageContainer {
                            SwiftUI.Image(uiImage: container.image).resizable().aspectRatio(contentMode: fit ? .fit : .fill)
                                .transition(.opacity)
                        } else if state.error != nil {
                            failureView
                        } else {
                            placeholder
                        }
                    }
                    .pipeline(MMEvidenceImages.pipeline)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: url)
                } else if failed {
                    failureView
                } else {
                    placeholder
                }
            }
            .clipped()
            .task(id: path) {
                guard override?(path) == nil else { return }
                failed = false
                if MMEvidenceImages.hasCachedData(path: path) {
                    url = MMEvidenceImages.cacheURL(for: path)
                } else if let resolved = await resolve(path) {
                    url = resolved
                } else {
                    failed = true
                }
            }
    }

    private var failureView: some View {
        placeholder.overlay(
            SwiftUI.Image(systemName: "photo")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(MoveMarkTheme.Light.textTertiary)
        )
    }
}
