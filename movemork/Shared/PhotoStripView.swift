//
//  PhotoStripView.swift
//  movemork
//
//  MoveMark — Horizontal photo strip: real thumbnails or count placeholders.
//

import SwiftUI
import UIKit

struct PhotoStripView: View {
    private let images: [UIImage]
    private let placeholderCount: Int?

    /// Pre-save / local picks: show actual thumbnails.
    init(images: [UIImage]) {
        self.images = images
        self.placeholderCount = nil
    }

    /// When only a count is known (e.g. hero summarizing saved proof without loaded UIImages).
    init(placeholderCount: Int) {
        self.images = []
        self.placeholderCount = max(0, placeholderCount)
    }

    var body: some View {
        if !images.isEmpty {
            HStack(spacing: 10) {
                ForEach(Array(images.prefix(4).enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.55), lineWidth: 0.9)
                        )
                }

                if images.count > 4 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MoveMarkTheme.Colors.surfaceInset.opacity(0.9))
                            .frame(width: 64, height: 64)

                        Text("+\(images.count - 4)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.92))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.5), lineWidth: 0.9)
                    )
                }
            }
        } else if let count = placeholderCount, count > 0 {
            placeholderStrip(count: count)
        }
    }

    private func placeholderStrip(count: Int) -> some View {
        HStack(spacing: 10) {
            ForEach(0..<min(max(count, 1), 4), id: \.self) { idx in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MoveMarkTheme.Colors.mint.opacity(idx == 0 ? 0.85 : 0.45))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(idx == 0 ? MoveMarkTheme.Colors.accent.opacity(0.75) : MoveMarkTheme.Colors.panelStroke.opacity(0.55), lineWidth: 1)
                    )
            }

            if count > 4 {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MoveMarkTheme.Colors.surfaceInset.opacity(0.88))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text("+\(count - 4)")
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.5), lineWidth: 0.9)
                    )
            }
        }
    }
}
