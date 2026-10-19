//
//  RoomEvidenceHero.swift
//  movemork
//
//  @file Room hero — full-bleed evidence photo with filmstrip, or the empty capture field
//  @domain proof-capture
//  @status wip
//  @see [[ROOM_EVIDENCE_RECORD]] — screen spec (§4 composition)
//  @see [[VISUAL_STANDARD]] — one hero, sans type, glass only over evidence
//  @see [[RoomEvidenceHero.kt]] — Android counterpart
//

import SwiftUI
import PhotosUI

/// What to photograph in an empty room. Tagging damage and notes now live in the form on both
/// platforms, so they are no longer prompts.
enum RoomCapturePrompts {
    static let items = [
        "A wide shot from the doorway",
        "Walls and baseboards",
        "Floors",
        "Windows / blinds",
    ]
}

struct RoomEvidenceHero: View {
    let roomName: String
    let entries: [EvidenceRecord]
    let moveOutMode: Bool
    /// Height of the top safe area — the photo runs under the status bar and nav bar.
    let topInset: CGFloat
    /// Screen size, for a hero crop that leaves the body visible on small phones.
    let containerSize: CGSize
    let resolvePhotoURL: (String) async -> URL?
    var onOpenPhoto: (EvidencePhoto) -> Void = { _ in }

    // Empty-state capture (the screen's green action when nothing is saved yet).
    var hasPendingPhotos: Bool = false
    var isBusy: Bool = false
    var onTakePhotos: () -> Void = {}
    var pickerSelection: Binding<[PhotosPickerItem]>? = nil

    /// Room-level comparison line ("MOVE-IN 4 · MOVE-OUT 3 PHOTOS"), when both phases have photos.
    var compareLine: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPhotoID: UUID?
    @State private var heroURL: URL?

    /// Newest entry first, then each entry's photos in capture order.
    private var orderedEntries: [EvidenceRecord] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    private var allPhotos: [(photo: EvidencePhoto, entry: EvidenceRecord)] {
        orderedEntries.flatMap { entry in entry.photos.map { (photo: $0, entry: entry) } }
    }

    private var current: (photo: EvidencePhoto, entry: EvidenceRecord)? {
        if let selectedPhotoID, let match = allPhotos.first(where: { $0.photo.id == selectedPhotoID }) {
            return match
        }
        return allPhotos.first
    }

    private var photoCount: Int { entries.reduce(0) { $0 + $1.photoCount } }
    private var issueCount: Int { Set(entries.flatMap(\.issueTags)).count }

    var body: some View {
        if let current {
            documented(current)
        } else {
            emptyField
        }
    }

    // MARK: - Documented

    private func documented(_ current: (photo: EvidencePhoto, entry: EvidenceRecord)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                // Fixed-size frame with the image in an overlay: a fill-cropped image must never
                // widen the screen (it pushed the body off the right edge).
                Color.clear
                    .frame(width: containerSize.width, height: heroHeight)
                    .overlay { photoLayer(current.photo) }
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { onOpenPhoto(current.photo) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("\(roomName) evidence photo")
                    .accessibilityHint("Opens the photo full screen")

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.35), location: 0),
                        .init(color: .clear, location: 0.2),
                        .init(color: .black.opacity(0.18), location: 0.4),
                        .init(color: MoveMarkTheme.Colors.appBackground.opacity(0.78), location: 0.72),
                        .init(color: MoveMarkTheme.Colors.appBackground.opacity(0.95), location: 0.9),
                        .init(color: MoveMarkTheme.Colors.appBackground, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 10) {
                    kicker(moveOutMode ? "Move-out evidence" : "Move-in evidence", color: .white.opacity(0.78))
                    Text(roomName)
                        .font(MoveMarkTheme.Typography.roomTitle)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) { chips(current.entry) }
                        VStack(alignment: .leading, spacing: 6) { chips(current.entry) }
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.bottom, 14)
                // Real photos are often pale walls; a soft shadow keeps the title legible at any text size.
                .shadow(color: .black.opacity(0.35), radius: 10, y: 1)
            }

            VStack(alignment: .leading, spacing: 14) {
                recordedLine(current.entry.createdAt)
                if allPhotos.count > 1 {
                    filmstrip(selectedID: current.photo.id)
                }
                if let compareLine {
                    Text(compareLine)
                        .font(MoveMarkTheme.Typography.monoMeta)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 6)
        }
        .task(id: current.photo.id) { await loadHero(current.photo) }
    }

    private var heroHeight: CGFloat {
        // Portrait-leaning crop that still leaves the body visible on small phones.
        min(containerSize.width * 1.18, containerSize.height * 0.58) + topInset
    }

    @ViewBuilder
    private func photoLayer(_ photo: EvidencePhoto) -> some View {
        MMCachedAsyncImage(path: photo.filePath, signedURL: heroURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
                    .transition(.opacity)
            case .empty:
                MoveMarkTheme.Colors.card
                    .overlay(ProgressView().tint(.white.opacity(0.7)))
            case .failure:
                MoveMarkTheme.Colors.card.overlay(
                    Label("Photo unavailable", systemImage: "photo")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                )
            }
        }
        .id(photo.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: photo.id)
    }

    @ViewBuilder
    private func chips(_ entry: EvidenceRecord) -> some View {
        glassChip(entry.condition.rawValue)
        glassChip(photoCount == 1 ? "1 photo" : "\(photoCount) photos")
        if issueCount > 0 {
            glassChip(issueCount == 1 ? "1 issue" : "\(issueCount) issues", attention: true)
        }
    }

    /// Glass is allowed here: the chip sits over evidence (VISUAL_STANDARD).
    private func glassChip(_ text: String, attention: Bool = false) -> some View {
        HStack(spacing: 5) {
            if attention {
                Circle().fill(MoveMarkTheme.Colors.semanticWarning).frame(width: 6, height: 6)
            }
            Text(text)
                .font(MoveMarkTheme.Typography.tinyEmphasis)
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .environment(\.colorScheme, .dark)
    }

    private func recordedLine(_ date: Date) -> some View {
        let label = kicker("Recorded", color: MoveMarkTheme.Colors.textMuted)
        let value = Text(Self.recordedFormatter.string(from: date).uppercased())
            .font(MoveMarkTheme.Typography.monoMeta)
            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            .fixedSize()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { label; value }
            VStack(alignment: .leading, spacing: 2) { label; value }
        }
        .accessibilityElement(children: .combine)
    }

    private func filmstrip(selectedID: UUID) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allPhotos, id: \.photo.id) { item in
                    RoomEvidenceThumb(
                        photo: item.photo,
                        isSelected: item.photo.id == selectedID,
                        resolvePhotoURL: resolvePhotoURL
                    )
                    .onTapGesture {
                        MMHaptics.soft()
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                            selectedPhotoID = item.photo.id
                        }
                    }
                    .accessibilityAddTraits(item.photo.id == selectedID ? [.isButton, .isSelected] : .isButton)
                    .accessibilityLabel("Photo from \(Self.recordedFormatter.string(from: item.entry.createdAt))")
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    // MARK: - Empty

    private var emptyField: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                kicker(moveOutMode ? "Move-out evidence" : "Move-in evidence", color: MoveMarkTheme.Colors.textMuted)
                Text(roomName)
                    .font(MoveMarkTheme.Typography.roomTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 8) {
                    Circle().fill(MoveMarkTheme.Colors.semanticWarning).frame(width: 7, height: 7)
                    Text("Still needs proof")
                        .font(MoveMarkTheme.Typography.sectionTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                }
                Text(moveOutMode
                     ? "Photograph each surface before you return the keys."
                     : "Photograph it before boxes cover anything.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, topInset + 64)

            VStack(alignment: .leading, spacing: 12) {
                kicker("What to capture", color: MoveMarkTheme.Colors.textMuted)
                ForEach(RoomCapturePrompts.items, id: \.self) { prompt in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "viewfinder")
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        Text(prompt)
                            .font(MoveMarkTheme.Typography.body)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 30)

            VStack(spacing: 10) {
                // Green only while it is the screen's one action; once photos are picked the
                // save bar takes over the green.
                MMButton(
                    title: "Take photos",
                    action: onTakePhotos,
                    kind: hasPendingPhotos ? .secondary : .primary,
                    size: .standard,
                    isDisabled: isBusy
                )
                if let pickerSelection {
                    RoomGalleryPicker(selection: pickerSelection, isDisabled: isBusy)
                }
            }
            .padding(.top, 30)
        }
        .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .top) {
            LinearGradient(
                colors: [MoveMarkTheme.Colors.cardRaised.opacity(0.85), MoveMarkTheme.Colors.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: topInset + 360)
        }
    }

    // MARK: - Helpers

    private func kicker(_ text: String, color: Color) -> some View {
        Text(text)
            .font(MoveMarkTheme.Typography.kicker)
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    private func loadHero(_ photo: EvidencePhoto) async {
        heroURL = nil
        heroURL = await resolvePhotoURL(photo.filePath)
    }

    static let recordedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d · h:mm a"
        return f
    }()
}

/// 64pt filmstrip thumbnail; prefers the small thumbnail object.
private struct RoomEvidenceThumb: View {
    let photo: EvidencePhoto
    let isSelected: Bool
    let resolvePhotoURL: (String) async -> URL?
    @State private var url: URL?

    var body: some View {
        MMCachedAsyncImage(path: photo.thumbnailPath ?? photo.filePath, signedURL: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .empty: MoveMarkTheme.Colors.cardRaised
            case .failure:
                MoveMarkTheme.Colors.cardRaised.overlay(
                    Image(systemName: "photo").foregroundStyle(MoveMarkTheme.Colors.textMuted)
                )
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        )
        .opacity(isSelected ? 1 : 0.72)
        .task(id: photo.id) {
            if let thumb = photo.thumbnailPath, let resolved = await resolvePhotoURL(thumb) {
                url = resolved
            } else {
                url = await resolvePhotoURL(photo.filePath)
            }
        }
    }
}

/// "Choose from gallery" — secondary, never green.
struct RoomGalleryPicker: View {
    let selection: Binding<[PhotosPickerItem]>
    var isDisabled: Bool = false
    var compact: Bool = false

    var body: some View {
        PhotosPicker(selection: selection, maxSelectionCount: 20, matching: .images) {
            Label(compact ? "Gallery" : "Choose from gallery", systemImage: "photo.on.rectangle.angled")
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .padding(.vertical, 4)
                // Same surface as MMButton(.secondary, .standard) so the two capture actions match.
                .background(
                    RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.button, style: .continuous)
                        .fill(MoveMarkTheme.Surface.interactive)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.button, style: .continuous)
                        .stroke(MoveMarkTheme.Stroke.interactive, lineWidth: 1)
                )
        }
        .disabled(isDisabled)
    }
}
