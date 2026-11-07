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

    /// The room brief's shot list: the same four shots, each with a quiet symbol.
    static let shots: [(prompt: String, symbol: String)] = zip(items, [
        "door.left.hand.open",
        "square.split.1x2",
        "square.grid.3x3",
        "window.vertical.closed",
    ]).map { (prompt: $0, symbol: $1) }
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
    /// The newest photo not saved yet: the evidence frame shows it, so the brief turns into the record.
    var pendingPreview: UIImage? = nil
    var pendingCount: Int = 0
    /// The brief fills the screen and holds its actions at the bottom, unless something follows it (the new
    /// entry form, or a notice, which must not be pushed below the fold).
    var fillsScreen: Bool = false

    /// Room-level comparison line ("MOVE-IN 4 · MOVE-OUT 3 PHOTOS"), when both phases have photos.
    var compareLine: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Everything in the brief except the evidence frame, for sizing the frame to the screen.
    @ScaledMetric(relativeTo: .body) private var briefChrome: CGFloat = 480
    @ScaledMetric(relativeTo: .body) private var captionSize: CGFloat = 15
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
                // Free while the text fits on the poster (it is bottom-aligned). At the largest text sizes a long
                // room name makes it taller than the poster; this keeps it below the status bar instead of under it.
                .padding(.top, topInset + 12)
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
    /// black on white over the photo). Opens camera or library. Once photos are picked the save bar holds
    /// the lime, so this turns neutral (same rule as the empty-state "Take photos").
    private var addEvidencePill: some View {
        Button {
            MMHaptics.soft()
            showAddChoice = true
        } label: {
            Label("Add evidence", systemImage: "camera.fill")
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
    }

    private func photoLayer(_ photo: EvidencePhoto) -> some View {
        MMEvidenceImage(path: photo.filePath, resolve: resolvePhotoURL, size: CGSize(width: containerSize.width, height: heroHeight),
                        placeholder: MoveMarkTheme.Colors.card)
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
            LazyHStack(spacing: 8) {
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

    /// The room brief: which room and its state, the frame this room's proof will fill, the shots to take,
    /// and the one action. The frame borrows Welcome's registration marks: what MoveMark records goes inside.
    private var emptyField: some View {
        VStack(alignment: .leading, spacing: 0) {
            briefIdentity
                .padding(.top, topInset + 20)

            evidenceAperture
                .padding(.top, 20)

            shotList
                .padding(.top, 20)

            Spacer(minLength: 18)

            briefActions
        }
        .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, minHeight: fillsScreen ? briefHeight : nil, alignment: .topLeading)
        .background(alignment: .top) {
            LinearGradient(
                colors: [MoveMarkTheme.Colors.cardRaised.opacity(0.85), MoveMarkTheme.Colors.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: topInset + 360)
        }
    }

    /// The visible page: the screen, less the scroll tail under the brief.
    private var briefHeight: CGFloat {
        containerSize.height + topInset - MoveMarkTheme.Spacing.scrollTailFocusedFlow
    }

    /// As tall as the screen allows, up to a 5:4 frame; never so small it stops reading as a photograph.
    private var apertureHeight: CGFloat {
        let width = containerSize.width - MoveMarkTheme.Spacing.screenHorizontal * 2
        let tallest = width * 0.8
        guard fillsScreen, !dynamicTypeSize.isAccessibilitySize else { return min(tallest, 200) }
        return min(tallest, max(116, briefHeight - topInset - briefChrome))
    }

    private var briefIdentity: some View {
        VStack(alignment: .leading, spacing: 6) {
            kicker(moveOutMode ? "Move-out evidence" : "Move-in evidence", color: MoveMarkTheme.Colors.textMuted)
            Text(roomName)
                .font(MoveMarkTheme.Typography.roomTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(pendingCount > 0 ? "Not saved yet" : "No proof yet")
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
    }

    /// Waiting for its first photo, then showing the newest one. Unfinished on purpose, never a broken image.
    private var evidenceAperture: some View {
        ZStack(alignment: .bottomLeading) {
            if let pendingPreview {
                Color.clear
                    .overlay {
                        Image(uiImage: pendingPreview)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .accessibilityElement()
                    .accessibilityLabel("Newest photo of \(roomName), not saved yet")
                    .transition(.opacity)
                // Real photos are often pale walls: keeps the marks and the count legible on any of them.
                LinearGradient(colors: [.black.opacity(0.3), .clear, .clear, .black.opacity(0.45)],
                               startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                glassChip(pendingCount == 1 ? "1 photo" : "\(pendingCount) photos", icon: "photo.on.rectangle", tint: .white)
                    .padding(14)
                    .accessibilityHidden(true)
            } else {
                MoveMarkTheme.Colors.appBackgroundRaised.opacity(0.7)
                Text("This room’s record starts with your first photo.")
                    .font(.system(size: captionSize, weight: .regular, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 20)
            }
            RegistrationMarks(length: 14)
                .stroke(.white.opacity(0.7), lineWidth: 1)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        // The caption can grow the empty frame at the largest text sizes; a photo stays in its crop.
        .frame(minHeight: apertureHeight, maxHeight: pendingPreview == nil ? nil : apertureHeight)
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: pendingCount)
    }

    /// A photographer's shot list, not a checklist: nothing here reads as already done.
    private var shotList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(moveOutMode ? "Capture these before you return the keys" : "Capture these before you unpack")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            ForEach(Array(RoomCapturePrompts.shots.enumerated()), id: \.offset) { index, shot in
                Rectangle()
                    .fill(MoveMarkTheme.Colors.divider)
                    .frame(height: 1)
                    .accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(String(format: "%02d", index + 1))
                        .font(MoveMarkTheme.Typography.monoMeta)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        .accessibilityHidden(true)
                    Text(shot.prompt)
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: shot.symbol)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 9)
            }
        }
    }

    private var briefActions: some View {
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
            content.photosPicker(isPresented: $isPresented, selection: selection, maxSelectionCount: 20, matching: .images,
                                 preferredItemEncoding: .current)
        } else {
            content
        }
    }
}
