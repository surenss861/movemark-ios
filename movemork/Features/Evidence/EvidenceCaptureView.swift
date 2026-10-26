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
    /// The receipt's "Continue to next room" (opens another room in place) and, once every room has proof,
    /// "View move-in report". Without them the receipt just returns to this room.
    var onOpenRoom: ((UUID) -> Void)? = nil
    var onOpenReport: (() -> Void)? = nil

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
    /// The receipt shown after every save (full or partial).
    @State var savedReceipt: SavedRoomReceipt? = nil
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
            // A hard edge under the save bar: iOS's soft scroll-edge effect let the page show through it.
            .scrollEdgeEffectStyle(.hard, for: .bottom)
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
        .fullScreenCover(item: $savedReceipt) { receipt in
            SavedRoomReceiptScreen(receipt: receipt) { action in
                savedReceipt = nil
                handleReceiptAction(action, receipt: receipt)
            }
        }
        .fullScreenCover(item: $previewTarget) { target in
            RoomPhotoViewer(
                photos: RoomEvidenceHero.orderedPhotos(existingEntries).map(\.photo),
                startID: target.id,
                subject: roomName,
                captions: RoomPhotoViewer.captions(for: existingEntries),
                resolvePhotoURL: resolvePhotoURL,
                onClose: { previewTarget = nil }
            )
        }
        .onChange(of: selectedItems) { _, newItems in
            loadSelectedItems(newItems)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(
                roomName: roomName,
                pendingCount: loadedImages.count,
                prompts: RoomCapturePrompts.items,
                onCapture: { fileData in
                    // The camera's encoded capture file is the source evidence, untouched; the camera stays
                    // open for the next shot.
                    guard let source = try? MMEvidenceImport.source(from: fileData, captureSource: .camera) else { return false }
                    var selection = MMEvidenceSelection(sources: loadedSources, previews: loadedImages)
                    selection.append(source)
                    guard selection.sources.count > loadedSources.count else { return false }
                    loadedSources = selection.sources
                    loadedImages = selection.previews
                    return true
                },
                onDone: { showCamera = false },
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
            // The brief already says which proof it is; the documented room has no other phase label.
            if !existingEntries.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Text(moveOutMode ? "Move-out" : "Move-in")
                    .font(MoveMarkTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .accessibilityLabel(moveOutMode ? "Move-out evidence" : "Move-in evidence")
            }
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
                ProofPhotoGridView(images: loadedImages, isUploading: isUploading,
                                   onRemove: { removePendingPhoto(at: $0) })
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

    func presentCameraIfAllowed() {
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
struct EditEvidenceSheet: View {
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
            MMEvidenceSheetScaffold(title: "Edit proof") {
                Text("Update the title, notes, issue tags and condition of this saved entry in \(roomName).")
                    .mmFont(14.5)
                    .foregroundStyle(MMInk.heroSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if evidence.photoCount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        MMEvidenceCaption(title: "Photos on file", detail: evidence.photoCount == 1 ? "1 photo" : "\(evidence.photoCount) photos")
                        MMEvidencePhotoStrip(placeholderCount: evidence.photoCount)
                    }
                    .padding(.top, 20)
                }

                VStack(alignment: .leading, spacing: 20) {
                    MMEvidenceField(title: "Entry title", placeholder: "e.g. North wall", text: $title)
                    MMEvidenceField(title: "Notes", placeholder: "What matters, where it is", text: $notes, axis: .vertical)
                    MMEvidenceTagPicker(tags: fixedIssueTags, selected: $selectedTags, onToggle: { MMHaptics.selection() })
                    MMEvidenceConditionPicker(condition: $condition)
                }
                .disabled(isSaving)
                .padding(.top, 22)

                if let localEditError {
                    MMEvidenceNotice(
                        message: localEditError,
                        actionTitle: MMCopy.tryAgain,
                        action: { Task { await commitSave() } }
                    )
                    .padding(.top, 20)
                }
            } footer: {
                MMPrimaryButton(title: isSaving ? "Saving…" : "Save changes", isLoading: isSaving, isDisabled: isSaving) {
                    Task { await commitSave() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .disabled(isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
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
struct AppendPhotosSheet: View {
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
            MMEvidenceSheetScaffold(title: "Add photos") {
                Text("Add to “\(entry.title)”. New photos are saved with this entry’s record.")
                    .mmFont(14.5)
                    .foregroundStyle(MMInk.heroSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if entry.photoCount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        MMEvidenceCaption(title: "On this entry", detail: entry.photoCount == 1 ? "1 photo" : "\(entry.photoCount) photos")
                        MMEvidencePhotoStrip(placeholderCount: entry.photoCount)
                    }
                    .padding(.top, 20)
                }

                PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .images, preferredItemEncoding: .current) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 16))
                            .frame(width: 24)
                        Text(loadedImages.isEmpty ? "Choose photos from library" : "Change selection")
                            .mmFont(16)
                        Spacer(minLength: 8)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(MMInk.heroSecondary)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: MMMetrics.rowHeight)
                    .background(MMInk.evidenceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(MMInk.evidenceStroke, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(MMLightPressStyle())
                .disabled(isUploading || retryPending != nil)
                .onChange(of: selectedItems) { _, new in
                    loadItems(new)
                }
                .padding(.top, 22)

                if loadedImages.isEmpty {
                    MMEvidenceNotice(
                        message: "No new photos selected. Pick one or more — they’re saved as part of this entry.",
                        tone: .info
                    )
                    .padding(.top, 14)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        MMEvidenceCaption(title: "Ready to add", detail: loadedImages.count == 1 ? "1 new photo" : "\(loadedImages.count) new photos")
                        MMEvidencePhotoStrip(images: loadedImages)
                    }
                    .padding(.top, 18)
                }

                if let localError {
                    MMEvidenceNotice(
                        message: localError,
                        actionTitle: MMCopy.tryAgain,
                        action: { Task { await commitAppend() } }
                    )
                    .padding(.top, 14)
                }
            } footer: {
                VStack(spacing: 8) {
                    Text(bottomPrimaryLine)
                        .mmFont(13)
                        .foregroundStyle(MMInk.heroSecondary)
                    MMPrimaryButton(
                        title: isUploading ? "Adding…" : "Add to entry",
                        isLoading: isUploading,
                        isDisabled: loadedImages.isEmpty || isUploading
                    ) {
                        Task { await commitAppend() }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .disabled(isUploading)
                }
            }
            .interactiveDismissDisabled(isUploading)
        }
    }

    private var bottomPrimaryLine: String {
        if isUploading { return "Adding photos…" }
        if loadedImages.isEmpty { return "Select photos to continue" }
        return "\(loadedImages.count) photo\(loadedImages.count == 1 ? "" : "s") ready to add"
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
