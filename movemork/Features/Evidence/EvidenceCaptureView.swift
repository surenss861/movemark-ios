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
    @Environment(\.dismiss) private var dismiss
    /// True when pushed (there is a system back to guard); false as a stack root (first run has its own Back).
    @Environment(\.isPresented) private var isPresented

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
    /// First run's own Back (this view is a stack root there); it asks first when photos are unsaved.
    var onBack: (() -> Void)? = nil

    @State var title = ""
    @State var notes = ""
    @State var selectedTags: Set<String> = []
    @State var selectedCondition: RoomRecord.ConditionRating = .good
    @State var selectedItems: [PhotosPickerItem] = []
    @State var loadedImages: [UIImage] = []
    /// Source evidence for each pending photo (index-aligned with `loadedImages`, which are previews only).
    /// Each keeps one id from capture on: its file in the pending store and its `evidence_files` row id.
    @State var loadedSources: [MMPendingEvidence] = []
    /// Ids of the pending photos that came from the current Photos picker selection (in selection order);
    /// camera shots and photos restored from this iPhone are not part of it.
    @State var pickerItemIDs: [UUID] = []
    @State var isUploading = false
    /// How many photos the running save is sending (the status line's count).
    @State var uploadingCount = 0
    /// The last save attempt didn't confirm the photos still pending (or the app stopped during one).
    @State var uploadFailed = false
    /// Restored partial save being checked against the server (no upload yet).
    @State var isCheckingSaved = false
    /// The pending set restored for this key already (restore runs once per room open).
    @State var restoredKey: PendingEvidenceKey? = nil
    var pendingCenter: PendingEvidenceCenter { PendingEvidenceCenter.shared }
    static let newEntryAnchor = "evidence.newEntry"
    @State var isLoadingHistory = false
    /// Set after a save where not every photo made it; cleared once the rest are saved.
    @State var pendingRetry: EvidenceRetryState? = nil
    @State var errorMessage: String? = nil
    /// What raised `errorMessage`, so its "Try again" repeats that (save, delete, history load) or is hidden.
    @State var errorSource: EvidenceErrorSource = .none
    @State var isDeleting = false
    @State private var showDiscardConfirm = false
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

    /// Photos picked or shot but not saved yet, or a partial save still waiting for its retry.
    var hasUnsavedPhotos: Bool { !loadedImages.isEmpty || pendingRetry != nil }

    /// This room's pending store: per user, rental, room and phase.
    var pendingKey: PendingEvidenceKey? {
        guard let userId = sessionManager.userId, let propertyId = propertyStore.currentProperty?.id else { return nil }
        return PendingEvidenceKey(userId: userId, propertyId: propertyId, roomId: roomID, stage: moveOutMode ? .moveOut : .moveIn)
    }

    /// The one factual line about the unsaved photos: on this iPhone, uploading, or failed.
    var syncState: MMEvidenceSyncState? {
        if isUploading { return .uploading(count: max(uploadingCount, 1)) }
        guard hasUnsavedPhotos else { return nil }
        if uploadFailed || pendingRetry != nil { return .failed }
        return .savedLocally
    }

    var currentDraft: PendingEvidenceDraft {
        PendingEvidenceDraft(title: title, notes: notes, tags: selectedTags, condition: selectedCondition)
    }

    /// Back asks before leaving: only where there is a system back to replace.
    private var guardsBack: Bool { hasUnsavedPhotos && isPresented }

    private var unsavedPhotoCount: Int { loadedImages.count + (pendingRetry?.pending.count ?? 0) }

    /// "Try again" for the current notice; nil hides the button.
    private var retryAction: (() -> Void)? {
        if errorMessage != nil {
            switch errorSource {
            case .save: return { saveEvidence() }
            case .delete(let id): return { Task { await deleteEntry(id) } }
            case .history(let load): return { loadHistory(load) }
            case .none: break
            }
        }
        // A partial save's status line retries its remaining photos.
        guard pendingRetry != nil else { return nil }
        return { saveEvidence() }
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
                        // A new save would replace a partial save's retry state: finish that first.
                        isBusy: isUploading || pendingRetry != nil,
                        onTakePhotos: { presentCameraIfAllowed() },
                        pickerSelection: $selectedItems,
                        pendingPreview: loadedImages.last,
                        pendingCount: loadedImages.count,
                        fillsScreen: !hasUnsavedPhotos && errorMessage == nil && successMessage == nil,
                        compareLine: compareLine
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        if !existingEntries.isEmpty {
                            RoomEvidenceBody(
                                entries: existingEntries,
                                moveOutMode: moveOutMode,
                                isBusy: isUploading || isDeleting,
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

                        if hasUnsavedPhotos {
                            newEntrySection
                                .id(Self.newEntryAnchor)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else if errorMessage != nil || successMessage != nil {
                            // A message alone never brings up the empty New entry form.
                            standaloneNotices
                                .padding(.vertical, 18)
                        }
                    }
                    .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                    .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
                    .animation(MMMotion.cardReveal, value: loadedImages.count)
                }
            }
            .ignoresSafeArea(edges: .top)
            .scrollDismissesKeyboard(.interactively)
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
            SavedRoomReceiptScreen(receipt: receipt, resolvePhotoURL: resolvePhotoURL) { action in
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
                onCapture: { capture in
                    // The camera's encoded capture file is the source evidence, untouched. It is written to this
                    // iPhone first and only then shown as taken; the camera stays open for the next shot.
                    await admitCapture(capture)
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
                onDelete: {
                    editingEntry = nil
                    Task { await deleteEntry(entry.id) }
                },
                onDismiss: { editingEntry = nil }
            )
        }
        .sheet(item: $appendPhotosEntry) { entry in
            AppendPhotosSheet(
                entry: entry,
                pendingKey: appendKey(entry.id),
                roomName: roomName,
                onAdd: { await appendPhotos(to: entry.id) },
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
        // Unsaved photos are never dropped silently: the system back (and its swipe) gives way to a Back
        // that asks first.
        .navigationBarBackButtonHidden(guardsBack)
        .confirmationDialog(
            unsavedPhotoCount == 1 ? "Discard 1 unsaved photo?" : "Discard \(unsavedPhotoCount) unsaved photos?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                discardPendingCaptures()
                if let onBack { onBack() } else { dismiss() }
            }
            Button("Keep editing", role: .cancel) {}
        }
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if hasUnsavedPhotos { showDiscardConfirm = true } else { onBack() }
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel("Back")
                    .foregroundStyle(.white)
                    .disabled(isUploading)
                }
            } else if guardsBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDiscardConfirm = true
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel("Back")
                    .disabled(isUploading)
                }
            }
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
        // Photos left on this iPhone by an earlier visit (or a crash / kill) come back into the form.
        .task(id: pendingKey) { await restorePendingCaptures() }
        .onChange(of: currentDraft) { _, draft in persistDraft(draft) }
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
            EvidenceNewEntryHeader(moveOutMode: moveOutMode, photoCount: loadedImages.count,
                                   syncState: syncState, onRetry: { saveEvidence() })
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
                onRetry: retryAction
            )
        }
        .padding(.vertical, 18)
    }

    /// The form's notices, on their own when there is nothing to save (history load, delete, camera).
    private var standaloneNotices: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage {
                MMEvidenceNotice(
                    message: errorMessage,
                    actionTitle: retryAction == nil ? nil : MMCopy.tryAgain,
                    action: retryAction
                )
            }
            if let successMessage {
                MMEvidenceNotice(message: successMessage, tone: .success)
            }
        }
    }

    /// Older entries / remaining photos, loaded on demand (snapshot v2 loads the newest first).
    private func loadHistory(_ load: @escaping () async throws -> Void) {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        Task { @MainActor in
            defer { isLoadingHistory = false }
            do {
                try await load()
                if case .history = errorSource { errorMessage = nil; errorSource = .none }
            } catch {
                errorMessage = MoveMarkFlowMessage.proofHistoryLoadFailed(error)
                errorSource = .history(load)
            }
        }
    }

    func presentCameraIfAllowed() {
        MoveMarkCameraPermission.requestPresentationIfEligible(
            onPresentCamera: { showCamera = true },
            onNeedsSettingsAlert: { showCameraPermissionAlert = true },
            onUnavailableMessage: { errorMessage = $0; errorSource = .none }
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
    /// Removes the entry after the native confirmation; nil hides Delete.
    var onDelete: (() -> Void)?
    let onDismiss: () -> Void

    @State private var confirmDelete = false
    @State private var title: String
    @State private var notes: String
    @State private var selectedTags: Set<String>
    @State private var condition: RoomRecord.ConditionRating
    @State private var isSaving = false
    @State private var localEditError: String?
    @State private var confirmDiscard = false

    init(
        evidence: EvidenceRecord,
        roomName: String,
        onSave: @escaping (String, String, [String], RoomRecord.ConditionRating) async -> String?,
        onDelete: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.evidence = evidence
        self.roomName = roomName
        self.onSave = onSave
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        _title = State(initialValue: evidence.title)
        _notes = State(initialValue: evidence.notes)
        _selectedTags = State(initialValue: Set(evidence.issueTags))
        _condition = State(initialValue: evidence.condition)
    }

    private let inspectionRepo = InspectionRepository()

    /// Anything differs from the saved record: Cancel and swipe-down ask before dropping it.
    private var hasChanges: Bool {
        title != evidence.title || notes != evidence.notes
            || selectedTags != Set(evidence.issueTags) || condition != evidence.condition
    }

    /// "Living Room · Move-in" — the record being edited.
    private var subject: String { "\(roomName) · \(evidence.stage.rawValue)" }

    private var meta: String {
        let when = evidence.createdAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
        let photos = evidence.photoCount == 1 ? "1 photo" : "\(evidence.photoCount) photos"
        return evidence.photoCount > 0 ? "Recorded \(when) · \(photos)" : "Recorded \(when)"
    }

    var body: some View {
        NavigationStack {
            MMEvidenceSheetScaffold(title: "") {
                MMEvidenceSheetHeader(eyebrow: "Edit evidence", subject: subject, meta: meta)

                if evidence.photoCount > 0 {
                    MMEvidenceRecordPhotos(photos: evidence.photos, photoCount: evidence.photoCount,
                                           resolve: { try? await inspectionRepo.signedURL(bucket: "inspection-media", path: $0) })
                        .padding(.top, 18)
                }

                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        MMEvidenceSectionLabel(title: "Condition")
                        FlowLayout(spacing: 8) {
                            // Best → worst, every stored value (incl. "Below fair") so a record never loses its rating.
                            ForEach(RoomRecord.ConditionRating.allCases.reversed(), id: \.self) { rating in
                                MMEvidenceChip(title: rating.rawValue, isSelected: condition == rating) {
                                    MMHaptics.selection()
                                    condition = rating
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        MMEvidenceSectionLabel(title: "What was observed",
                                               detail: selectedTags.isEmpty ? "Only if relevant" : "\(selectedTags.count) noted")
                        FlowLayout(spacing: 8) {
                            ForEach(fixedIssueTags, id: \.self) { tag in
                                MMEvidenceChip(title: tag, isSelected: selectedTags.contains(tag)) {
                                    MMHaptics.selection()
                                    if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        MMEvidenceSectionLabel(title: "Notes")
                        MMEvidenceField(title: "Label", placeholder: "e.g. North wall", text: $title,
                                        accessibilityID: "Entry title")
                        MMEvidenceField(title: "Notes", placeholder: "What you saw, and where", text: $notes, axis: .vertical)
                    }
                }
                .disabled(isSaving)
                .padding(.top, 26)

                if let localEditError {
                    MMEvidenceNotice(
                        message: localEditError,
                        actionTitle: MMCopy.tryAgain,
                        action: { Task { await commitSave() } }
                    )
                    .padding(.top, 20)
                }
            } footer: {
                VStack(spacing: 6) {
                    MMPrimaryButton(title: isSaving ? "Saving…" : "Save changes", isLoading: isSaving, isDisabled: isSaving) {
                        Task { await commitSave() }
                    }
                    if onDelete != nil {
                        // Quiet and well below Save; the native alert is the safety, not a danger panel.
                        Button("Delete evidence") { confirmDelete = true }
                            .mmFont(15, .medium)
                            .foregroundStyle(MMInk.danger)
                            .frame(minHeight: 44)
                            .disabled(isSaving)
                    }
                }
            }
            .alert("Delete this evidence?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { onDelete?() }
            } message: {
                Text("Photos and notes for this entry will be removed. This can't be undone.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if hasChanges { confirmDiscard = true } else { onDismiss() } }
                        .disabled(isSaving)
                }
            }
            .mmDiscardChangesConfirmation(isPresented: $confirmDiscard, onDiscard: onDismiss)
            .interactiveDismissDisabled(isSaving || hasChanges)
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
/// Photos for an existing entry. Every photo chosen here is written to this iPhone (keyed to the entry)
/// before it appears, restored if the app stops with the sheet open, and leaves the phone only once the
/// server confirms its row; a retry reuses the same row ids.
struct AppendPhotosSheet: View {
    let entry: EvidenceRecord
    /// The entry's Add photos set on this iPhone (nil only in snapshots).
    let pendingKey: PendingEvidenceKey?
    let roomName: String
    /// Sends the set; returns the photos still needing a retry and a message (empty when all were added).
    let onAdd: () async -> (pending: [MMPendingEvidence], message: String?)
    let onDismiss: () -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var loadedIds: [UUID] = []
    @State private var isUploading = false
    @State private var localError: String?
    /// After a partial append (or a restore of one): exactly the photos that didn't make it. Picker
    /// changes are ignored until they're saved, so photos already added can't be picked up and sent again.
    @State private var retryPending = false
    @State private var confirmDiscard = false
    @State private var restored = false

    private var center: PendingEvidenceCenter { PendingEvidenceCenter.shared }

    init(
        entry: EvidenceRecord,
        pendingKey: PendingEvidenceKey? = nil,
        roomName: String = "",
        onAdd: @escaping () async -> (pending: [MMPendingEvidence], message: String?),
        onDismiss: @escaping () -> Void,
        previewImages: [UIImage] = []
    ) {
        self.entry = entry
        self.pendingKey = pendingKey
        self.roomName = roomName
        self.onAdd = onAdd
        self.onDismiss = onDismiss
        // Snapshot seam only: pending previews without a store (the app always loads them through the store).
        _loadedImages = State(initialValue: previewImages)
    }

    /// "North wall · Move-in evidence" — the record the photos join (the sheet knows the entry, not the room).
    private var subject: String { "\(entry.title) · \(entry.stage.rawValue) evidence" }

    private var meta: String? {
        guard entry.photoCount > 0 else { return nil }
        return entry.photoCount == 1 ? "1 photo on this record" : "\(entry.photoCount) photos on this record"
    }

    private var hasPending: Bool { !loadedImages.isEmpty }

    /// Photos chosen (or left over from a partial add) that aren't on the record yet.
    private var hasChanges: Bool { hasPending || retryPending }

    var body: some View {
        NavigationStack {
            MMEvidenceSheetScaffold(title: "", showsFooter: hasPending || isUploading) {
                MMEvidenceSheetHeader(eyebrow: "Add photos", subject: subject, meta: meta)

                // No camera path reaches this sheet today, so the only choice is the library (never a fake one).
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .images, preferredItemEncoding: .current) {
                    MMEvidenceChoiceLabel(
                        icon: "photo.on.rectangle",
                        title: hasPending ? "Choose different photos" : "Choose from Photos",
                        detail: hasPending ? "Replace the photos below." : "Add existing photos from your library."
                    )
                }
                .buttonStyle(MMLightPressStyle())
                .disabled(isUploading || retryPending)
                .onChange(of: selectedItems) { _, new in
                    loadItems(new)
                }
                .padding(.top, 24)

                if hasPending {
                    VStack(alignment: .leading, spacing: 12) {
                        MMEvidenceSectionLabel(title: loadedImages.count == 1 ? "1 photo ready" : "\(loadedImages.count) photos ready")
                        MMPendingPhotoGrid(images: loadedImages, isUploading: isUploading)
                    }
                    .padding(.top, 28)
                }

                if let localError {
                    MMEvidenceNotice(
                        message: localError,
                        actionTitle: MMCopy.tryAgain,
                        action: { Task { await commitAppend() } }
                    )
                    .padding(.top, 18)
                }
            } footer: {
                MMPrimaryButton(
                    title: isUploading ? "Adding…" : "Add to evidence",
                    isLoading: isUploading,
                    isDisabled: loadedImages.isEmpty || isUploading
                ) {
                    Task { await commitAppend() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if hasChanges { confirmDiscard = true } else { onDismiss() } }
                        .disabled(isUploading)
                }
            }
            .mmDiscardChangesConfirmation(isPresented: $confirmDiscard, onDiscard: discard)
            .interactiveDismissDisabled(isUploading || hasChanges)
            .task { await restore() }
        }
    }

    /// Photos this set left on the iPhone (the app stopped with the sheet open, or a partial add).
    private func restore() async {
        guard !restored, let pendingKey else { return }
        restored = true
        await center.flush()
        guard let set = await center.store.restore(pendingKey), !set.items.isEmpty else { return }
        loadedIds = set.items.map(\.item.id)
        loadedImages = set.items.map(\.preview)
        retryPending = set.manifest.savedCount > 0 || set.items.contains { $0.item.status != .pending }
    }

    private func commitAppend() async {
        guard !isUploading else { return }
        localError = nil
        guard !loadedImages.isEmpty else {
            MMHaptics.warning()
            localError = "Choose at least one photo to add."
            return
        }
        let previews = Dictionary(uniqueKeysWithValues: zip(loadedIds, loadedImages))

        isUploading = true
        let (pending, message) = await onAdd()
        isUploading = false

        if pending.isEmpty, message == nil {
            onDismiss()
            return
        }
        localError = message
        retryPending = true
        loadedIds = pending.map(\.id)
        loadedImages = pending.compactMap { previews[$0.id] }
    }

    private func loadItems(_ items: [PhotosPickerItem]) {
        guard !retryPending, let pendingKey else { return }
        Task { @MainActor in
            let selection = await MMEvidencePicker.load(items)
            let picked = selection.sources.map { MMPendingEvidence(source: $0) }
            let replaced = loadedIds
            // The new choice replaces the old one, on this iPhone first; shown only once it is on disk.
            await center.perform(pendingKey.userId) { await $0.remove(replaced, from: pendingKey) }.value
            do {
                try await center.admit(picked.map { PendingEvidenceInput(id: $0.id, source: $0.source) },
                                       to: pendingKey, roomName: roomName)
                loadedIds = picked.map(\.id)
                loadedImages = selection.previews
                localError = selection.rejectionMessage
            } catch {
                loadedIds = []
                loadedImages = []
                selectedItems = []
                localError = EvidenceCaptureView.keepFailedMessage
            }
        }
    }

    private func discard() {
        if let pendingKey {
            center.perform(pendingKey.userId) { await $0.clearRoom(pendingKey) }
            Task { _ = await center.reconcile(pendingKey) }
        }
        onDismiss()
    }
}

extension View {
    /// The native "Discard changes?" question for a sheet with unsaved edits (Keep editing / Discard).
    func mmDiscardChangesConfirmation(isPresented: Binding<Bool>, onDiscard: @escaping () -> Void) -> some View {
        confirmationDialog("Discard changes?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Discard", role: .destructive, action: onDiscard)
            Button("Keep editing", role: .cancel) {}
        }
    }
}
