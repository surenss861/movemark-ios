//
//  MMVaultProofHeroCard.swift
//  movemork
//
//  The vault's one star: this rental as a case file. Coverage is rooms documented.
//

import SwiftUI

struct MMVaultProofHeroCard: View {
    let propertyName: String
    var location: String? = nil
    var coverageLabel: String = "Move-in coverage"
    let coverageLine: String
    var statsLine: String? = nil
    var nextRoomName: String? = nil
    let progress: Double
    var previewPath: String? = nil
    var previewURL: URL? = nil
    let primaryTitle: String
    let onPrimary: () -> Void
    var reportReadyLine: String? = nil
    var onViewReport: (() -> Void)? = nil
    var documentedCount: Int? = nil
    var totalRooms: Int? = nil
    var photoCount: Int? = nil
    var recordCount: Int? = nil
    var issueCount: Int? = nil
    var lastProofLine: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double { min(1, max(0, progress)) }

    private var showsFigure: Bool {
        guard let totalRooms, totalRooms > 0, documentedCount != nil else { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            identity

            coverageBlock

            if showsStats {
                statsRow
            }

            if let lastProofLine, !lastProofLine.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("LAST PROOF ADDED")
                        .font(MoveMarkTheme.Typography.kicker)
                        .tracking(1.05)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    Text(lastProofLine)
                        .font(MoveMarkTheme.Typography.monoMeta)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }

            if let nextRoomName, !nextRoomName.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT")
                        .font(MoveMarkTheme.Typography.kicker)
                        .tracking(1.05)
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                    Text(nextRoomName)
                        .font(MoveMarkTheme.Typography.rowTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
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
        .mmCaseFilePlate(emphasis: true)
    }

    private var identity: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(propertyName)
                    .font(MoveMarkTheme.Typography.editorialTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(6)
                    .minimumScaleFactor(0.55)

                if let location, !location.isEmpty {
                    Text(location)
                        .font(MoveMarkTheme.Typography.metadata)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if previewURL != nil {
                proofThumbnail
            }
        }
    }

    @ViewBuilder
    private var coverageBlock: some View {
        if showsFigure, let documentedCount, let totalRooms {
            HStack(alignment: .center, spacing: 12) {
                MMCoverageFigure(
                    documented: documentedCount,
                    total: totalRooms,
                    kicker: coverageLabel
                )
                Spacer(minLength: 8)
                ProgressRingView(progress: clampedProgress, size: 68, lineWidth: 3.5)
                    .accessibilityHidden(true)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(coverageLabel.uppercased())
                    .font(MoveMarkTheme.Typography.kicker)
                    .tracking(1.05)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                Text(coverageLine)
                    .font(MoveMarkTheme.Typography.rowTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                if let statsLine, !statsLine.isEmpty {
                    Text(statsLine)
                        .font(MoveMarkTheme.Typography.metadata)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }
        }
    }

    private var showsStats: Bool {
        photoCount != nil || recordCount != nil || issueCount != nil
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: 0) {
            if let photoCount {
                statCell(value: photoCount, label: photoCount == 1 ? "Photo" : "Photos")
            }
            if let recordCount {
                statCell(value: recordCount, label: recordCount == 1 ? "Record" : "Records")
            }
            if let issueCount {
                statCell(
                    value: issueCount,
                    label: issueCount == 1 ? "Issue" : "Issues",
                    valueColor: issueCount > 0 ? MoveMarkTheme.Colors.semanticWarning : MoveMarkTheme.Colors.textPrimary
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func statCell(value: Int, label: String, valueColor: Color = MoveMarkTheme.Colors.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(MoveMarkTheme.Typography.statFigure)
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(MoveMarkTheme.Typography.kicker)
                .tracking(0.8)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : MMMotion.proofProgress, value: value)
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
                    case .empty, .failure:
                        MoveMarkTheme.Surface.interactive
                    }
                }
            } else {
                MoveMarkTheme.Surface.interactive
            }
        }
        .frame(width: 64, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
        }
        .accessibilityLabel("Latest proof photo")
    }
}
