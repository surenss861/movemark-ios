//
//  MMRoomEvidencePlate.swift
//  movemork
//
//  @file Room hero: the room's evidence plate, with the latest photo as the star
//  @domain design-system
//  @status wip
//  @see [[ROOM_EVIDENCE_RECORD]] — screen spec
//  @see [[VISUAL_STANDARD]] — hierarchy, type voices, glass rules
//  @see [[MMRoomEvidencePlate.kt]] — Android counterpart
//

import SwiftUI

/// Room hero. With saved photos for the phase it shows the latest one large, with glass chips
/// (condition, photo count, issues) and a mono "recorded" time; without photos it is an empty
/// capture surface reading "Still needs proof". It never adds a green action of its own.
struct MMRoomEvidencePlate: View {
    let roomName: String
    let room: RoomRecord?
    let moveOutMode: Bool
    /// Resolves a storage path to a loadable URL (signed in the app, a local file in QA fixtures).
    let resolvePhotoURL: (String) async -> URL?

    @State private var heroURL: URL?

    private var entries: [EvidenceRecord] {
        guard let room else { return [] }
        return moveOutMode ? room.moveOutEvidence : room.evidence
    }

    /// Most recent entry that actually has a photo; its first photo is the hero.
    private var latestWithPhoto: EvidenceRecord? {
        entries
            .filter { !$0.photos.isEmpty }
            .max(by: { $0.createdAt < $1.createdAt })
    }

    private var heroPhoto: EvidencePhoto? { latestWithPhoto?.photos.first }
    private var photoCount: Int { entries.reduce(0) { $0 + $1.photoCount } }
    private var issueCount: Int { entries.reduce(0) { $0 + $1.issueTags.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(moveOutMode ? "Move-out evidence" : "Move-in evidence")
                    .font(MoveMarkTheme.Typography.kicker)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)

                Text(roomName)
                    .font(MoveMarkTheme.Typography.editorialTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }

            if let heroPhoto, let latest = latestWithPhoto {
                photoPlate(heroPhoto, latest: latest)
                recordedLine(latest.createdAt)
            } else {
                emptyPlate
            }

            phaseCompareLine
        }
        .task(id: heroPhoto?.id) { await loadHeroURL() }
    }

    // MARK: - Documented

    private func photoPlate(_ photo: EvidencePhoto, latest: EvidenceRecord) -> some View {
        Color.clear
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay {
                MMCachedAsyncImage(path: photo.thumbnailPath ?? photo.filePath, signedURL: heroURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        MoveMarkTheme.Colors.card.overlay(ProgressView().tint(MoveMarkTheme.Colors.textMuted))
                    case .failure:
                        MoveMarkTheme.Colors.card.overlay(
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        )
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                // One row when it fits; stacked at large Dynamic Type so no chip truncates.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { chips(latest) }
                    VStack(alignment: .leading, spacing: 6) { chips(latest) }
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Latest \(roomName) photo. Condition \(latest.condition.rawValue). \(photoCount) photos"
                    + (issueCount > 0 ? ", \(issueCount) issues" : "")
            )
    }

    @ViewBuilder
    private func chips(_ latest: EvidenceRecord) -> some View {
        glassChip(latest.condition.rawValue)
        glassChip(photoCount == 1 ? "1 photo" : "\(photoCount) photos")
        if issueCount > 0 {
            glassChip(issueCount == 1 ? "1 issue" : "\(issueCount) issues")
        }
    }

    /// Glass is allowed here because the chip sits over evidence (see VISUAL_STANDARD).
    private func glassChip(_ text: String) -> some View {
        Text(text)
            .font(MoveMarkTheme.Typography.tinyEmphasis)
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
    }

    private func recordedLine(_ date: Date) -> some View {
        let label = Text("Recorded")
            .font(MoveMarkTheme.Typography.kicker)
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
        let value = Text(Self.recordedFormatter.string(from: date).uppercased())
            .font(MoveMarkTheme.Typography.monoMeta)
            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            .fixedSize()
        // The timestamp never breaks mid-value; at large sizes it drops under its label.
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { label; value }
            VStack(alignment: .leading, spacing: 2) { label; value }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Empty

    private var emptyPlate: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: "camera")
                .font(.title2)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            Text("Still needs proof")
                .font(MoveMarkTheme.Typography.sectionTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            if !moveOutMode {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ProofSprint.roomShotPrompts, id: \.self) { prompt in
                        Text(prompt)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("Photograph each surface before you return the keys.")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    MoveMarkTheme.Colors.textMuted.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
        )
    }

    // MARK: - Phase comparison

    @ViewBuilder
    private var phaseCompareLine: some View {
        if let room {
            let moveIn = room.evidence.reduce(0) { $0 + $1.photoCount }
            let moveOut = room.moveOutEvidence.reduce(0) { $0 + $1.photoCount }
            if moveIn > 0, moveOut > 0 {
                Text("MOVE-IN \(moveIn) · MOVE-OUT \(moveOut) PHOTOS")
                    .font(MoveMarkTheme.Typography.monoMeta)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
        }
    }

    // MARK: - Loading

    private func loadHeroURL() async {
        guard let photo = heroPhoto else { heroURL = nil; return }
        let path = photo.thumbnailPath ?? photo.filePath
        if let url = await resolvePhotoURL(path) {
            heroURL = url
        } else if path != photo.filePath {
            heroURL = await resolvePhotoURL(photo.filePath)
        }
    }

    private static let recordedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d · h:mm a"
        return f
    }()
}
