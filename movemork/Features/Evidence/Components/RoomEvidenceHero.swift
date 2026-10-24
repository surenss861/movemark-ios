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
    @State private var showAddChoice = false
    @State private var showLibrary = false

    /// Newest entry first, then each entry's photos in capture order. The viewer pages in this order too.
    static func orderedPhotos(_ entries: [EvidenceRecord]) -> [(photo: EvidencePhoto, entry: EvidenceRecord)] {
        entries.sorted { $0.createdAt > $1.createdAt }
            .flatMap { entry in entry.photos.map { (photo: $0, entry: entry) } }
    }

    /// Hero height — shared with the screen so the nav title knows when the hero has left.
    static func heroHeight(container: CGSize, topInset: CGFloat) -> CGFloat {
        // The poster: about two-thirds of the screen, never so tall the body disappears on small phones.
        min(container.width * 1.35, container.height * 0.66) + topInset
    }

    private var allPhotos: [(photo: EvidencePhoto, entry: EvidenceRecord)] { Self.orderedPhotos(entries) }

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
                    .visualEffect { content, proxy in
                        // Pull down: the photo stretches from its bottom edge. Scroll up: it drifts
                        // slower than the page (parallax). Off under Reduce Motion.
                        let y = proxy.frame(in: .scrollView).minY
                        guard !reduceMotion else { return content.scaleEffect(1).offset(y: 0) }
                        let h = max(proxy.size.height, 1)
                        return content
                            .scaleEffect(y > 0 ? 1 + y / h : 1, anchor: .bottom)
                            .offset(y: y < 0 ? -y * 0.4 : 0)
                    }
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

                // Layered on the poster: state first, then the room, then provenance, then the action.
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) { chips(current.entry) }
                        VStack(alignment: .leading, spacing: 6) { chips(current.entry) }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(roomName)
                            .font(MoveMarkTheme.Typography.roomTitle)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        recordedLine(current.entry.createdAt, onPhoto: true)
                    }
                    // Real photos are often pale walls; a soft shadow keeps the title legible at any text size.
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 1)
                    addEvidencePill
                        .padding(.top, 6)
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.bottom, 18)
            }

            VStack(alignment: .leading, spacing: 14) {
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
            .padding(.top, 8)
        }
        .confirmationDialog("Add evidence", isPresented: $showAddChoice, titleVisibility: .hidden) {
            Button("Take photos") { onTakePhotos() }
            Button("Choose from library") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .modifier(LibraryPickerModifier(isPresented: $showLibrary, selection: pickerSelection))
    }

    private var heroHeight: CGFloat { Self.heroHeight(container: containerSize, topInset: topInset) }

    /// The room's action, in the same lime as every MoveMark action (dark text on lime reads as clearly as
    /// black on white over the photo). Opens camera or library.
    private var addEvidencePill: some View {
        Button {
            MMHaptics.soft()
            showAddChoice = true
        } label: {
            Label("Add evidence", systemImage: "camera.fill")
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(Self.onLime)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Self.lime, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.5 : 1)
    }

    private func photoLayer(_ photo: EvidencePhoto) -> some View {
        MMEvidenceImage(path: photo.filePath, resolve: resolvePhotoURL, placeholder: MoveMarkTheme.Colors.card)
            .id(photo.id)
            .transition(.opacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: photo.id)
    }

    @ViewBuilder
    private func chips(_ entry: EvidenceRecord) -> some View {
        glassChip(entry.condition.rawValue, icon: "checkmark.circle.fill", tint: MoveMarkTheme.Colors.primary)
        glassChip(photoCount == 1 ? "1 photo" : "\(photoCount) photos", icon: "photo.on.rectangle", tint: .white)
        if issueCount > 0 {
            glassChip(
                issueCount == 1 ? "1 issue" : "\(issueCount) issues",
                icon: "exclamationmark.triangle.fill",
                tint: MoveMarkTheme.Colors.semanticWarning
            )
        }
    }

    /// Glass is allowed here: the chip sits over evidence (VISUAL_STANDARD).
    private func glassChip(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(MoveMarkTheme.Typography.tinyEmphasis)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(MoveMarkTheme.Typography.tinyEmphasis)
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .environment(\.colorScheme, .dark)
    }

    private func recordedLine(_ date: Date, onPhoto: Bool = false) -> some View {
        let label = kicker("Recorded", color: onPhoto ? .white.opacity(0.7) : MoveMarkTheme.Colors.textMuted)
        let value = Text(Self.recordedFormatter.string(from: date).uppercased())
            .font(MoveMarkTheme.Typography.monoMeta)
            .foregroundStyle(onPhoto ? .white.opacity(0.9) : MoveMarkTheme.Colors.textSecondary)
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

    /// The room brief: which room, that it has no proof yet, what to photograph, and the one action.
    private var emptyField: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                kicker(moveOutMode ? "Move-out evidence" : "Move-in evidence", color: MoveMarkTheme.Colors.textMuted)
                Text(roomName)
                    .font(MoveMarkTheme.Typography.roomTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("No proof yet")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
            .padding(.top, topInset + 28)

            VStack(alignment: .leading, spacing: 12) {
                Text(moveOutMode ? "Capture these before you return the keys:" : "Capture these before you unpack:")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            .padding(.top, 26)

            VStack(spacing: 6) {
                // The one action, in the Vault's lime; once photos are picked the save bar takes over.
                Button(action: onTakePhotos) {
                    Label("Take photos", systemImage: "camera.fill")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(hasPendingPhotos ? MoveMarkTheme.Colors.textPrimary : Self.onLime)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background(hasPendingPhotos ? AnyShapeStyle(MoveMarkTheme.Surface.interactive) : AnyShapeStyle(Self.lime),
                                    in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .opacity(isBusy ? 0.5 : 1)
                if let pickerSelection {
                    RoomGalleryPicker(selection: pickerSelection, isDisabled: isBusy, quiet: true)
                }
            }
            .padding(.top, 26)
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

    /// The Vault's action colour (#CAE36C), so capture continues the same signal.
    static let lime = Color(red: 0.792, green: 0.890, blue: 0.424)
    static let onLime = Color(red: 0.067, green: 0.086, blue: 0.035)

    // MARK: - Helpers

    private func kicker(_ text: String, color: Color) -> some View {
        Text(text)
            .font(MoveMarkTheme.Typography.kicker)
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(color)
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

    var body: some View {
        MMEvidenceImage(path: photo.thumbnailPath ?? photo.filePath, resolve: resolvePhotoURL,
                        size: CGSize(width: 64, height: 64), placeholder: MoveMarkTheme.Colors.cardRaised)
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .opacity(isSelected ? 1 : 0.72)
    }
}

/// "Choose from gallery" — secondary, never green.
struct RoomGalleryPicker: View {
    let selection: Binding<[PhotosPickerItem]>
    var isDisabled: Bool = false
    var compact: Bool = false
    /// A text action under the primary button (the room brief), not a second full-width control.
    var quiet: Bool = false

    var body: some View {
        if quiet {
            PhotosPicker(selection: selection, maxSelectionCount: 20, matching: .images, preferredItemEncoding: .current) {
                Text("Choose from Photos")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.9))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isDisabled)
        } else {
            boxed
        }
    }

    private var boxed: some View {
        PhotosPicker(selection: selection, maxSelectionCount: 20, matching: .images, preferredItemEncoding: .current) {
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

/// `.photosPicker` needs a binding; the gallery QA screen passes none.
private struct LibraryPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let selection: Binding<[PhotosPickerItem]>?

    func body(content: Content) -> some View {
        if let selection {
            content.photosPicker(isPresented: $isPresented, selection: selection, maxSelectionCount: 20, matching: .images)
        } else {
            content
        }
    }
}
