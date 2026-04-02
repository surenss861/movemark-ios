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
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if images.count > 4 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 60, height: 60)

                        Text("+\(images.count - 4)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
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
                    .fill(Color.white.opacity(idx == 0 ? 0.10 : 0.04))
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(idx == 0 ? MoveMarkTheme.Colors.accent : MoveMarkTheme.Colors.panelStroke, lineWidth: 1)
                    )
            }

            if count > 4 {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MoveMarkTheme.Colors.fieldFill)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text("+\(count - 4)")
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    )
            }
        }
    }
}
