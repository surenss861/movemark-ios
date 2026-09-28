//
//  MMVaultProofHeroCard.swift
//  movemork
//
//  Property hero on Proof: identity, move-in coverage, next room, one primary action.
//  Coverage is rooms documented — never a "score".
//

import SwiftUI

struct MMVaultProofHeroCard: View {
    let propertyName: String
    var location: String? = nil
    /// Small letterspaced label above the coverage line — "Move-in coverage".
    var coverageLabel: String = "Move-in coverage"
    /// "1 of 10 rooms documented".
    let coverageLine: String
    /// "1 photo · 1 of 2 records".
    var statsLine: String? = nil
    /// Room name for the "Next room" line; nil hides it.
    var nextRoomName: String? = nil
    let progress: Double
    var previewPath: String? = nil
    var previewURL: URL? = nil
    let primaryTitle: String
    let onPrimary: () -> Void
    /// Quiet trailing link when a report is already available ("Move-in report ready").
    var reportReadyLine: String? = nil
    var onViewReport: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double { min(1, max(0, progress)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                proofThumbnail

                VStack(alignment: .leading, spacing: 3) {
                    Text(propertyName)
                        .font(MoveMarkTheme.Typography.cardTitleCompact)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(2)

                    if let location, !location.isEmpty {
                        Text(location)
                            .font(MoveMarkTheme.Typography.metadata)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(coverageLabel.uppercased())
                    .font(MoveMarkTheme.Typography.tinyEmphasis)
                    .tracking(0.9)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)

                Text(coverageLine)
                    .font(MoveMarkTheme.Typography.rowTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                if let statsLine, !statsLine.isEmpty {
                    Text(statsLine)
                        .font(MoveMarkTheme.Typography.metadata)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }

                progressBar
                    .padding(.top, 6)

                if let nextRoomName, !nextRoomName.isEmpty {
                    HStack(spacing: 6) {
                        Text("Next room")
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        Text(nextRoomName)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    }
                    .font(MoveMarkTheme.Typography.detailMedium)
                    .padding(.top, 4)
                }
            }

            MMButton(
                title: primaryTitle,
                action: {
                    MMHaptics.soft()
                    onPrimary()
                },
                kind: .primary,
                size: .inline
            )

            if let reportReadyLine, let onViewReport {
                Button(action: onViewReport) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MoveMarkTheme.Colors.primary)
                        Text(reportReadyLine)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        Spacer(minLength: 8)
                        Text("View")
                            .foregroundStyle(MoveMarkTheme.Colors.primary)
                        Image(systemName: "chevron.right")
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.primary)
                    }
                    .font(MoveMarkTheme.Typography.detailMedium)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MoveMarkTheme.Spacing.panelPadding)
        .background(
            RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.hero, style: .continuous)
                .fill(MoveMarkTheme.Surface.raised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.hero, style: .continuous)
                .stroke(MoveMarkTheme.Stroke.interactive, lineWidth: 1)
        )
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
        .frame(width: 60, height: 60)
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
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 6)
                Capsule()
                    .fill(MoveMarkTheme.Colors.primary.opacity(clampedProgress > 0 ? 0.9 : 0.35))
                    .frame(width: max(6, geo.size.width * clampedProgress), height: 6)
                    .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clampedProgress)
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("Coverage")
        .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent")
    }
}
