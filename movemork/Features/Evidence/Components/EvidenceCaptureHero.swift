//
//  EvidenceCaptureHero.swift
//  movemork
//
//  Room header, move-in vs move-out compare, hero proof card.
//

import SwiftUI
import UIKit

struct EvidenceCaptureHero: View {
    let roomName: String
    let room: RoomRecord?
    let existingEntries: [EvidenceRecord]
    let roomID: UUID
    let selectedCondition: RoomRecord.ConditionRating
    /// In-memory picks before save (real thumbnails in hero strip when non-empty).
    let loadedImages: [UIImage]
    let loadedImageCount: Int
    let moveOutMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            roomHeader
            heroProofCard
        }
    }

    private var roomHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(roomName)
                .font(MoveMarkTheme.Typography.screenTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(
                moveOutMode
                    ? "Re-capture condition at move-out. Compare with move-in proof."
                    : "Capture proof clearly while the condition is still fresh."
            )
            .font(MoveMarkTheme.Typography.body)
            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            if let room {
                moveInVsMoveOutCompare(room: room)
            }

            Rectangle()
                .fill(MoveMarkTheme.Colors.accent)
                .frame(width: 38, height: 3)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func moveInVsMoveOutCompare(room: RoomRecord) -> some View {
        let moveInEntries = room.evidence.count
        let moveInPhotos = room.evidence.reduce(0) { $0 + $1.photoCount }
        let moveOutEntries = room.moveOutEvidence.count
        let moveOutPhotos = room.moveOutEvidence.reduce(0) { $0 + $1.photoCount }

        if moveInEntries == 0, moveOutEntries == 0, moveInPhotos == 0, moveOutPhotos == 0 {
            Text("No move-in or move-out proof yet")
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        } else {
            HStack(spacing: 6) {
                Text("Move-in: \(moveInEntries) \(moveInEntries == 1 ? "entry" : "entries"), \(moveInPhotos) photos")
                Text("·")
                Text("Move-out: \(moveOutEntries) \(moveOutEntries == 1 ? "entry" : "entries"), \(moveOutPhotos) photos")
            }
            .font(MoveMarkTheme.Typography.caption)
            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
    }

    private var heroVisualHeight: CGFloat {
        existingEntries.isEmpty ? 148 : 180
    }

    private var heroProofCard: some View {
        MMCard(tone: .artifact) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: heroVisualHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if existingEntries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.aperture")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.52))

                            Text("No proof captured yet")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.88))

                            Text("Start with room photos below")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.72))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let first = existingEntries.first {
                        Text(first.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.black.opacity(0.34))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .padding(12)
                    }
                }

                if !existingEntries.isEmpty || loadedImageCount > 0 {
                    if !loadedImages.isEmpty {
                        PhotoStripView(images: loadedImages)
                    } else {
                        PhotoStripView(placeholderCount: existingEntries.first?.photoCount ?? max(loadedImageCount, 1))
                    }
                }

                if let first = existingEntries.first, !first.issueTags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(first.issueTags.prefix(2), id: \.self) { tag in
                            MMPill(text: tag, tone: .warning)
                        }
                    }
                }

                ConditionMeter(
                    rating: existingEntries.first?.condition.conditionMeterValue
                        ?? selectedCondition.conditionMeterValue
                )

                heroSummaryRow

                HStack {
                    Text("REF")
                        .font(MoveMarkTheme.Typography.caption)
                        .tracking(1.2)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                    Spacer()

                    Text("MM-\(roomName.prefix(2).uppercased())-\(roomID.uuidString.prefix(6))")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var heroSummaryRow: some View {
        let totalEntries = existingEntries.count
        let totalPhotos = existingEntries.reduce(0) { $0 + $1.photoCount }
        let latest = existingEntries.first?.createdAt

        if totalEntries > 0 {
            HStack(spacing: 8) {
                Text("\(totalEntries) \(totalEntries == 1 ? "entry" : "entries")")
                Text("·")
                Text("\(totalPhotos) photos")
                if let latest {
                    Text("·")
                    Text("Latest \(latest.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .font(MoveMarkTheme.Typography.caption)
            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
    }
}
