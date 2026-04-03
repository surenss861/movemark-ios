//
//  VaultCoverBackground.swift
//  movemork
//
//  Cover area: image from URL or designed fallback. Zoom on press, overlay shade.
//

import SwiftUI
import NukeUI

struct VaultCoverBackground: View {
    let propertyId: UUID
    let imageURL: URL?
    let fallbackStyle: VaultFallbackStyle
    let isPressed: Bool
    var isEmphasized: Bool = false
    /// Mint fresh signed URLs and reload Nuke when the cover image fails (e.g. expired token).
    var onPreviewReloadRequested: (() -> Void)? = nil

    var body: some View {
        Group {
            if let url = imageURL {
                LazyImage(url: url, resizingMode: .aspectFill)
                    .onFailure { _ in
                        Task {
                            await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)
                            await MainActor.run { onPreviewReloadRequested?() }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VaultCoverFallback(style: fallbackStyle, isPressed: isPressed, isEmphasized: isEmphasized)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .scaleEffect(isPressed ? 1.02 : 1.0)
        .overlay(coverShade)
        .animation(MMMotion.press, value: isPressed)
    }

    /// Featured: cinematic transition so band feels like the base of one object. Non-featured: standard.
    private var coverShade: some View {
        LinearGradient(
            stops: isEmphasized
                ? [
                    .init(color: .white.opacity(0.05), location: 0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.65), location: 0.5),
                    .init(color: .black.opacity(isPressed ? 0.98 : 0.96), location: 1)
                ]
                : [
                    .init(color: .white.opacity(0.03), location: 0),
                    .init(color: .clear, location: 0.42),
                    .init(color: .black.opacity(0.5), location: 0.6),
                    .init(color: .black.opacity(isPressed ? 0.94 : 0.9), location: 1)
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
