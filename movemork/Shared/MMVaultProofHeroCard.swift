//
//  MMVaultProofHeroCard.swift
//  movemork
//
//  Evidence-first vault hero — photo, progress, one next action (not a dashboard tile).
//

import SwiftUI

struct MMVaultProofHeroCard: View {
    let propertyName: String
    var location: String? = nil
    let progressLine: String
    let nextLine: String
    let progress: Double
    var previewPath: String? = nil
    var previewURL: URL? = nil
    let primaryTitle: String
    let onPrimary: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double { min(1, max(0, progress)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                proofThumbnail

                VStack(alignment: .leading, spacing: 6) {
                    Text(propertyName)
                        .font(MoveMarkTheme.Typography.subtitleLarge)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(2)

                    if let location, !location.isEmpty {
                        Text(location)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                            .lineLimit(1)
                    }

                    Text(progressLine)
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .padding(.top, 2)

                    Text(nextLine)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            progressBar

            MMButton(
                title: primaryTitle,
                action: {
                    MMHaptics.soft()
                    onPrimary()
                },
                kind: .primary,
                size: .inline
            )
        }
        .padding(16)
        .mmProofCardSurface(.neutral, cornerRadius: 20)
    }

    @ViewBuilder
    private var proofThumbnail: some View {
        Group {
            if let previewURL {
                MMCachedAsyncImage(path: previewPath, signedURL: previewURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(1.14)
                            .brightness(0.06)
                            .contrast(1.06)
                    case .empty, .failure:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(previewURL == nil ? 0 : 0.05))
                .allowsHitTesting(false)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            MoveMarkTheme.Colors.artifactPaper.opacity(0.22)
            MoveMarkTheme.Colors.fieldFill.opacity(0.88)
            Image(systemName: "camera.fill")
                .font(MoveMarkTheme.Typography.cardTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.82))
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.85))
                    .frame(height: 4)
                Capsule()
                    .fill(MoveMarkTheme.Colors.primary.opacity(clampedProgress > 0 ? 0.9 : 0.35))
                    .frame(width: max(4, geo.size.width * clampedProgress), height: 4)
                    .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clampedProgress)
            }
        }
        .frame(height: 4)
    }
}
