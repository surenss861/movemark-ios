//
//  EvidenceCaptureView.swift
//  movemork
//
//  MoveMark — Room detail: hero proof, photo strip, condition, add proof, saved proof.
//

import SwiftUI
import PhotosUI
import UIKit

/// Fixed issue tags for the picker; must match seeded rows in `issue_tags`. Curated set for cleaner UI.
fileprivate let fixedIssueTags = [
    "Scratch",
    "Stain",
    "Water damage",
    "Chipped paint",
    "Cracked tile",
    "Appliance damage"
]

struct EvidenceCaptureView: View {
    @Environment(PropertyStore.self) var propertyStore
    @Environment(SessionManager.self) var sessionManager

    let roomID: UUID
    let roomName: String
    private let inspectionRepo = InspectionRepository()
    /// When true, show/save move-out proof; otherwise move-in.
    var moveOutMode: Bool = false
    /// First-run move-in: after first successful save, hand off to receipt screen.
    var onFirstProofSaved: ((FirstRunSavedSummary) -> Void)? = nil

    @State var title = ""
    @State var notes = ""
    @State var selectedTags: Set<String> = []
    @State var selectedCondition: RoomRecord.ConditionRating = .good
    @State var selectedItems: [PhotosPickerItem] = []
    @State var loadedImages: [UIImage] = []
    /// Source evidence for each pending photo (index-aligned with `loadedImages`, which are previews only).
    @State var loadedSources: [MMEvidenceSource] = []
    @State var isUploading = false
    static let newEntryAnchor = "evidence.newEntry"
    @State var isLoadingHistory = false
    /// Set after a save where not every photo made it; cleared once the rest are saved.
    @State var pendingRetry: EvidenceRetryState? = nil
    @State var errorMessage: String? = nil
    @State var successMessage: String? = nil
    @State var showCamera = false
    @State var editingEntry: EvidenceRecord? = nil
    @State var deleteConfirmEntry: EvidenceRecord? = nil
    @State var appendPhotosEntry: EvidenceRecord? = nil
    @State var appendPhotoItems: [PhotosPickerItem] = []
    @State var appendLoadedImages: [UIImage] = []
    @State var isAppendingPhotos = false
    @State var didJustSave = false
    @State var wasDocumentedOnLoad = false
    @State private var showCameraPermissionAlert = false
    @State var proofToast: MMProofToastMessage? = nil
    @State var proofToastVisible = false
    @State var proofScanlineTrigger = 0
    @State var previewTarget: RoomPhotoPreviewTarget? = nil
    @State var heroScrolledAway = false

    var room: RoomRecord? {
        propertyStore.currentProperty?.rooms.first(where: { $0.id == roomID })
    }

    var existingEntries: [EvidenceRecord] {
        if moveOutMode {
            return room?.moveOutEvidence ?? []
        }
        return room?.evidence ?? []
    }

    /// Move-in only: room is documented when it has at least one photo on file.
    var isRoomCurrentlyDocumented: Bool {
        guard let room else { return false }
        return MMRoomProofMetrics.isDocumented(room)
    }

    /// Room-level comparison when both phases have photos (shown under the hero).
    private var compareLine: String? {
        guard let room else { return nil }
        let moveIn = room.moveInPhotoTotal
        let moveOut = room.moveOutPhotoTotal
        guard moveIn > 0, moveOut > 0 else { return nil }
        return "MOVE-IN \(moveIn) · MOVE-OUT \(moveOut) PHOTOS"
    }

    /// Save bar appears only when there is something to save (or a save just happened).
    private var showsSaveBar: Bool {
        !loadedImages.isEmpty || isUploading || didJustSave
    }

    private func resolvePhotoURL(_ path: String) async -> URL? {
        try? await inspectionRepo.signedURL(bucket: "inspection-media", path: path)
    }

    private func openPreview(_ photo: EvidencePhoto) {
        previewTarget = RoomPhotoPreviewTarget(id: photo.id)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RoomEvidenceHero(
                        roomName: roomName,
                        entries: existingEntries,
                        moveOutMode: moveOutMode,
                        topInset: geo.safeAreaInsets.top,
                        containerSize: geo.size,
                        resolvePhotoURL: resolvePhotoURL,
                        onOpenPhoto: { openPreview($0) },
                        hasPendingPhotos: !loadedImages.isEmpty,
                        isBusy: isUploading,
                        onTakePhotos: { presentCameraIfAllowed() },
                        pickerSelection: $selectedItems,
                        compareLine: compareLine
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        if !existingEntries.isEmpty {
                            RoomEvidenceBody(
                                entries: existingEntries,
                                moveOutMode: moveOutMode,
                                isBusy: isUploading,
                                onEdit: { editingEntry = $0 },
                                onAddPhotos: { appendPhotosEntry = $0 },
                                onDelete: { deleteConfirmEntry = $0 },
                                totalEntries: moveOutMode ? room?.moveOutEntryTotal : room?.moveInEntryTotal,
                                hasOlderEntries: room?.hasOlderEntries(moveOut: moveOutMode) ?? false,
                                isLoadingOlder: isLoadingHistory,
                                onLoadOlder: { loadHistory { try await propertyStore.loadOlderEntries(roomID: roomID, moveOut: moveOutMode) } },
                                onShowAllPhotos: { entry in
                                    loadHistory { try await propertyStore.loadAllPhotos(entryId: entry.id, roomID: roomID, moveOut: moveOutMode) }
                                }
                            )
                            .padding(.top, 10)
                        }

                        if !loadedImages.isEmpty || errorMessage != nil || successMessage != nil || pendingRetry != nil {
                            newEntrySection
                                .id(Self.newEntryAnchor)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                    .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
                    .animation(MMMotion.cardReveal, value: loadedImages.count)
                }
            }
            .ignoresSafeArea(edges: .top)
            .onScrollGeometryChange(for: Bool.self) { g in
                // The title settles into the bar once the hero (or empty-state heading) has scrolled away.
                let threshold = existingEntries.isEmpty
                    ? 140
                    : RoomEvidenceHero.heroHeight(container: geo.size, topInset: geo.safeAreaInsets.top) - 90
                return g.contentOffset.y + g.contentInsets.top > threshold
            } action: { _, past in
                withAnimation(.easeInOut(duration: 0.2)) { heroScrolledAway = past }
            }
            // A partial save must be seen: bring its warning and retry button on screen.
            .onChange(of: pendingRetry?.statusLine) { _, line in
                guard line != nil else { return }
                withAnimation(MMMotion.cardReveal) { proxy.scrollTo(Self.newEntryAnchor, anchor: .bottom) }
            }
            }
        }
        .background(MoveMarkTheme.Colors.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if showsSaveBar {
                EvidenceCaptureBottomSaveBar(
                    photoCount: loadedImages.count,
                    tagCount: selectedTags.count,
                    condition: selectedCondition,
                    isUploading: isUploading,
                    didJustSave: didJustSave,
                    moveOutMode: moveOutMode,
                    onSave: { saveEvidence() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(MMMotion.cardReveal, value: showsSaveBar)
        .fullScreenCover(item: $previewTarget) { target in
            RoomPhotoViewer(
                photos: RoomEvidenceHero.orderedPhotos(existingEntries).map(\.photo),
                startID: target.id,
                resolvePhotoURL: resolvePhotoURL,
                onClose: { previewTarget = nil }
            )
        }
        .onChange(of: selectedItems) { _, newItems in
            loadSelectedItems(newItems)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(
                onCapture: { fileData in
                    // The camera's encoded capture file is the source evidence, untouched.
                    do {
                        var selection = MMEvidenceSelection(sources: loadedSources, previews: loadedImages)
                        selection.append(try MMEvidenceImport.source(from: fileData, captureSource: .camera))
                        loadedSources = selection.sources
                        loadedImages = selection.previews
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
        }
        .sheet(item: $editingEntry) { entry in
            EditEvidenceSheet(
                evidence: entry,
                roomName: roomName,
                onSave: { title, notes, tags, condition in
                    await saveEditedEvidence(entryId: entry.id, title: title, notes: notes, tags: tags, condition: condition)
                },
                onDismiss: { editingEntry = nil }
            )
        }
        .sheet(item: $appendPhotosEntry) { entry in
            AppendPhotosSheet(
                entry: entry,
                onAdd: { photos in
                    await appendPhotos(to: entry.id, photos: photos)
                },
                onDismiss: { appendPhotosEntry = nil }
            )
        }
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            Button("Open Settings") {
                MoveMarkCameraPermission.openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable camera access for MoveMark in Settings to take photos.")
        }
        .alert("Delete proof?", isPresented: Binding(get: { deleteConfirmEntry != nil }, set: { if !$0 { deleteConfirmEntry = nil } })) {
            Button("Cancel", role: .cancel) {
                deleteConfirmEntry = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = deleteConfirmEntry {
                    Task { await deleteEntry(entry.id) }
                }
                deleteConfirmEntry = nil
            }
        } message: {
            Text("Photos and notes for this entry will be removed. This can't be undone.")
        }
        .navigationTitle(roomName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The room name lives in the hero; keep the bar clear over the photo.
            ToolbarItem(placement: .principal) {
                Text(roomName)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .opacity(heroScrolledAway ? 1 : 0)
                    .accessibilityHidden(!heroScrolledAway)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text(moveOutMode ? "Move-out" : "Move-in")
                    .font(MoveMarkTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .accessibilityLabel(moveOutMode ? "Move-out evidence" : "Move-in evidence")
            }
        }
        .toolbarBackground(heroScrolledAway ? .visible : .hidden, for: .navigationBar)
        .toolbarBackground(MoveMarkTheme.Colors.appBackground.opacity(0.92), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .mmProofToast(message: proofToast, isVisible: proofToastVisible)
        .onAppear {
            wasDocumentedOnLoad = isRoomCurrentlyDocumented
            MoveMarkAnalytics.track(
                .roomStarted,
                properties: [
                    "room": roomName,
                    "move_out": moveOutMode ? "1" : "0",
                ]
            )
        }
    }

    private var newEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !existingEntries.isEmpty {
                Rectangle().fill(MoveMarkTheme.Colors.divider).frame(height: 0.5)
            }
            HStack {
                Text(moveOutMode ? "New move-out entry" : "New entry")
                    .font(MoveMarkTheme.Typography.kicker)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                Spacer()
                if !loadedImages.isEmpty {
                    Text(loadedImages.count == 1 ? "1 photo" : "\(loadedImages.count) photos")
                        .font(MoveMarkTheme.Typography.monoMeta)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
            }
            if !loadedImages.isEmpty {
                ProofPhotoGridView(images: loadedImages, isUploading: isUploading)
                    .mmScanline(trigger: proofScanlineTrigger, intensity: 0.1)
            } else if let pendingRetry {
                ProofPhotoGridView(images: pendingRetry.pendingPreviews, isUploading: isUploading)
            }
            EvidenceCaptureForm(
                title: $title,
                notes: $notes,
                selectedTags: $selectedTags,
                selectedCondition: $selectedCondition,
                selectedItems: $selectedItems,
                loadedImages: loadedImages,
                isUploading: isUploading,
                // A partial save stays visible until its remaining photos are saved.
                errorMessage: errorMessage ?? pendingRetry?.statusLine,
                successMessage: successMessage,
                moveOutMode: moveOutMode,
                fixedIssueTags: fixedIssueTags,
                onRetry: { saveEvidence() }
            )
        }
        .padding(.vertical, 18)
    }

    /// Older entries / remaining photos, loaded on demand (snapshot v2 loads the newest first).
    private func loadHistory(_ load: @escaping () async throws -> Void) {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        Task { @MainActor in
            defer { isLoadingHistory = false }
            do { try await load() } catch { errorMessage = MoveMarkFlowMessage.proofHistoryLoadFailed(error) }
        }
    }

    private func presentCameraIfAllowed() {
        MoveMarkCameraPermission.requestPresentationIfEligible(
            onPresentCamera: { showCamera = true },
            onNeedsSettingsAlert: { showCameraPermissionAlert = true },
            onUnavailableMessage: { errorMessage = $0 }
        )
    }

}

/// Which photo the viewer opens on; it pages through every photo in the phase.
struct RoomPhotoPreviewTarget: Identifiable {
    let id: UUID
}

// MARK: - Edit evidence sheet
private struct EditEvidenceSheet: View {
    let evidence: EvidenceRecord
    let roomName: String
    let onSave: (String, String, [String], RoomRecord.ConditionRating) async -> String?
    let onDismiss: () -> Void

    @State private var title: String
    @State private var notes: String
    @State private var selectedTags: Set<String>
    @State private var condition: RoomRecord.ConditionRating
    @State private var isSaving = false
    @State private var localEditError: String?

    init(
        evidence: EvidenceRecord,
        roomName: String,
        onSave: @escaping (String, String, [String], RoomRecord.ConditionRating) async -> String?,
        onDismiss: @escaping () -> Void
    ) {
        self.evidence = evidence
        self.roomName = roomName
        self.onSave = onSave
        self.onDismiss = onDismiss
        _title = State(initialValue: evidence.title)
        _notes = State(initialValue: evidence.notes)
        _selectedTags = State(initialValue: Set(evidence.issueTags))
        _condition = State(initialValue: evidence.condition)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MMCard(tone: .artifact, padding: 18, spacing: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Edit proof")
                                    .font(MoveMarkTheme.Typography.cardTitle)
                                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                                Text("Update the title, notes, issue markers, and condition for this saved entry.")
                                    .font(MoveMarkTheme.Typography.footnote)
                                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.82))
                            }

                            if evidence.photoCount > 0 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Photos on file")
                                        .font(MoveMarkTheme.Typography.caption)
                                        .tracking(0.9)
                                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                        .textCase(.uppercase)

                                    PhotoStripView(placeholderCount: evidence.photoCount)
                                        .padding(12)
                                        .background(MoveMarkTheme.Colors.fieldFill.opacity(0.65))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.42), lineWidth: 0.8)
                                        )
                                }
                            }

                            VStack(alignment: .leading, spacing: 16) {
                                MMTextField(title: "Entry title", placeholder: "e.g. North wall", text: $title)
                                MMTextField(title: "Notes", placeholder: "What matters, where it is", text: $notes)

                                issueTagPicker

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Condition")
                                        .font(MoveMarkTheme.Typography.caption)
                                        .tracking(0.9)
                                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                        .textCase(.uppercase)

                                    Picker("Condition", selection: $condition) {
                                        ForEach(RoomRecord.ConditionRating.allCases, id: \.self) { r in
                                            Text(r.rawValue).tag(r)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.55))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.38), lineWidth: 0.8)
                                )
                            }
                            .disabled(isSaving)

                            if let localEditError {
                                MMErrorBanner(
                                    message: localEditError,
                                    retryTitle: MMCopy.tryAgain,
                                    onRetry: {
                                        Task { await commitSave() }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.vertical, 16)
                .padding(.bottom, 88)
            }
            .mmEmeraldBackground()
            .navigationTitle("Edit proof")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .disabled(isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                editSaveChrome
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private var issueTagPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Issue tags")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))

                Text(
                    selectedTags.isEmpty
                        ? "Optional damage markers"
                        : "\(selectedTags.count) selected"
                )
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.68))
            }

            FlowLayout(spacing: 8) {
                ForEach(fixedIssueTags, id: \.self) { tag in
                    tagChip(tag)
                }
            }
        }
    }

    @ViewBuilder
    private func tagChip(_ tag: String) -> some View {
        let isSelected = selectedTags.contains(tag)

        Button {
            MMHaptics.selection()
            if isSelected {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        } label: {
            Text(tag)
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(
                    isSelected
                        ? MoveMarkTheme.Colors.textPrimary
                        : MoveMarkTheme.Colors.textSecondary.opacity(0.76)
                )
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? MoveMarkTheme.Colors.primary.opacity(0.18)
                                : MoveMarkTheme.Colors.cardRaised.opacity(0.5)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? MoveMarkTheme.Colors.primary.opacity(0.45)
                                : MoveMarkTheme.Colors.cardStroke,
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var editSaveChrome: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(editPrimaryChromeLine)
                    .font(MoveMarkTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text("Updates this saved proof entry.")
                    .font(MoveMarkTheme.Typography.tinyMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
            }

            Spacer(minLength: 0)

            Button {
                Task { await commitSave() }
            } label: {
                Text(isSaving ? "Saving…" : "Save changes")
                    .font(MoveMarkTheme.Typography.footnoteEmphasis)
                .foregroundStyle(MoveMarkTheme.Colors.textOnPrimary)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary.opacity(isSaving ? 0.72 : 1.0))
                )
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(MoveMarkTheme.Colors.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.cardStroke)
                .frame(height: 0.5)
        }
        .shadow(color: MoveMarkTheme.Colors.textPrimary.opacity(0.06), radius: 8, y: -2)
    }

    private var editPrimaryChromeLine: String {
        if isSaving { return "Saving changes…" }
        return "Review changes"
    }

    private func commitSave() async {
        localEditError = nil
        isSaving = true
        let err = await onSave(
            title.isEmpty ? roomName : title,
            notes,
            Array(selectedTags),
            condition
        )
        isSaving = false
        if let err {
            localEditError = err
        } else {
            onDismiss()
        }
    }
}

// MARK: - Append photos sheet
private struct AppendPhotosSheet: View {
    let entry: EvidenceRecord
    /// Returns the photos still needing a retry and a message; empty when everything was added.
    let onAdd: ([MMPendingEvidence]) async -> (pending: [MMPendingEvidence], message: String?)
    let onDismiss: () -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var loadedSources: [MMEvidenceSource] = []
    @State private var isUploading = false
    @State private var localError: String?
    /// After a partial append: exactly the photos that didn't make it. Picker changes are ignored until
    /// they're saved, so photos already added can't be picked up and sent again.
    @State private var retryPending: [MMPendingEvidence]? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MMCard(tone: .artifact, padding: 18, spacing: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add photos")
                                    .font(MoveMarkTheme.Typography.cardTitle)
                                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                                Text("Append to “\(entry.title)”. New shots upload with this entry’s record.")
                                    .font(MoveMarkTheme.Typography.footnote)
                                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if entry.photoCount > 0 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Current photos on entry")
                                        .font(MoveMarkTheme.Typography.caption)
                                        .tracking(0.9)
                                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                        .textCase(.uppercase)

                                    PhotoStripView(placeholderCount: entry.photoCount)
                                        .padding(12)
                                        .background(MoveMarkTheme.Colors.fieldFill.opacity(0.55))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.38), lineWidth: 0.8)
                                        )
                                }
                            }

                            PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .images, preferredItemEncoding: .current) {
                                HStack(spacing: 10) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(MoveMarkTheme.Typography.bodySmallEmphasis)
                                    Text(loadedImages.isEmpty ? "Choose photos from library" : "\(loadedImages.count) new photo\(loadedImages.count == 1 ? "" : "s") selected")
                                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                                }
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(MoveMarkTheme.Colors.fieldFill.opacity(0.88))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.65), lineWidth: 0.9)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .disabled(isUploading || retryPending != nil)
                            .onChange(of: selectedItems) { _, new in
                                loadItems(new)
                            }

                            if loadedImages.isEmpty {
                                MMCompactCallout(
                                    systemImage: "photo.badge.plus",
                                    title: "No new photos selected",
                                    message: "Pick one or more images. They’ll upload as part of this proof entry."
                                )
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("\(loadedImages.count) new photo\(loadedImages.count == 1 ? "" : "s") ready")
                                            .font(MoveMarkTheme.Typography.subheadlineMedium)
                                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.92))

                                        Spacer()

                                        MMPill(text: "Ready to append", tone: .success)
                                    }

                                    PhotoStripView(images: loadedImages)
                                        .padding(12)
                                        .background(MoveMarkTheme.Colors.fieldFill.opacity(0.65))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.4), lineWidth: 0.8)
                                        )
                                }
                            }

                            if let localError {
                                MMErrorBanner(
                                    message: localError,
                                    retryTitle: MMCopy.tryAgain,
                                    onRetry: { Task { await commitAppend() } }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.vertical, 16)
                .padding(.bottom, 88)
            }
            .mmEmeraldBackground()
            .navigationTitle("Add photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .disabled(isUploading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                appendBottomChrome
            }
            .interactiveDismissDisabled(isUploading)
        }
    }

    private var appendBottomChrome: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bottomPrimaryLine)
                    .font(MoveMarkTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(bottomPrimaryColor)

                Text("Appends to this entry’s gallery.")
                    .font(MoveMarkTheme.Typography.tinyMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
            }

            Spacer(minLength: 0)

            Button {
                Task { await commitAppend() }
            } label: {
                Text(isUploading ? "Adding…" : "Add to entry")
                    .font(MoveMarkTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(loadedImages.isEmpty ? MoveMarkTheme.Colors.textSecondary : MoveMarkTheme.Colors.textOnPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(
                        Capsule()
                            .fill(
                                loadedImages.isEmpty
                                    ? MoveMarkTheme.Colors.cardRaised.opacity(0.6)
                                    : MoveMarkTheme.Colors.primary.opacity(isUploading ? 0.72 : 1.0)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(loadedImages.isEmpty || isUploading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(MoveMarkTheme.Colors.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.cardStroke)
                .frame(height: 0.5)
        }
        .shadow(color: MoveMarkTheme.Colors.textPrimary.opacity(0.06), radius: 8, y: -2)
    }

    private var bottomPrimaryLine: String {
        if isUploading { return "Adding photos…" }
        if loadedImages.isEmpty { return "Select photos to continue" }
        return "\(loadedImages.count) photo\(loadedImages.count == 1 ? "" : "s") ready to append"
    }

    private var bottomPrimaryColor: Color {
        if loadedImages.isEmpty, !isUploading {
            return MoveMarkTheme.Colors.semanticWarning.opacity(0.95)
        }
        return MoveMarkTheme.Colors.textPrimary
    }

    private func commitAppend() async {
        guard !isUploading else { return }
        localError = nil
        let photos = retryPending ?? loadedSources.map { MMPendingEvidence(source: $0) }
        guard !photos.isEmpty else {
            MMHaptics.warning()
            localError = "Choose at least one photo to add."
            return
        }
        let previews = Dictionary(uniqueKeysWithValues: zip(photos.map(\.id), loadedImages))

        isUploading = true
        let (pending, message) = await onAdd(photos)
        isUploading = false

        if pending.isEmpty, message == nil {
            onDismiss()
            return
        }
        localError = message
        if !pending.isEmpty {
            retryPending = pending
            loadedImages = pending.compactMap { previews[$0.id] }
            loadedSources = pending.map(\.source)
        }
    }

    private func loadItems(_ items: [PhotosPickerItem]) {
        guard retryPending == nil else { return }
        Task { @MainActor in
            let selection = await MMEvidencePicker.load(items)
            loadedSources = selection.sources
            loadedImages = selection.previews
            localError = selection.rejectionMessage
        }
    }
}
