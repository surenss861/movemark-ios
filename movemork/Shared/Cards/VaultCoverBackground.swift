//
//  VaultCoverBackground.swift
//  movemork
//
//  Cover area: image from URL or mint fallback. Light bottom fade for text band.
//

import SwiftUI
import NukeUI

struct VaultCoverBackground: View {
    let propertyId: UUID
    let imageURL: URL?
    let fallbackStyle: VaultFallbackStyle
    let isPressed: Bool
    var isEmphasized: Bool = false
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

    private var coverShade: some View {
        LinearGradient(
            stops: imageURL != nil
                ? [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.45),
                    .init(color: MoveMarkTheme.Colors.panel.opacity(0.55), location: 0.72),
                    .init(color: MoveMarkTheme.Colors.panel.opacity(0.92), location: 1)
                ]
                : [
                    .init(color: .clear, location: 0),
                    .init(color: MoveMarkTheme.Colors.panel.opacity(0.35), location: 1)
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
