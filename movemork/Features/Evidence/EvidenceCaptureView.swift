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

    @State var title = ""
    @State var notes = ""
    @State var selectedTags: Set<String> = []
    @State var selectedCondition: RoomRecord.ConditionRating = .good
    @State var selectedItems: [PhotosPickerItem] = []
    @State var loadedImages: [UIImage] = []
    @State var isUploading = false
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

    var room: RoomRecord? {
        propertyStore.currentProperty?.rooms.first(where: { $0.id == roomID })
    }

    var existingEntries: [EvidenceRecord] {
        if moveOutMode {
            return room?.moveOutEvidence ?? []
        }
        return room?.evidence ?? []
    }

    /// Move-in only: room is documented when it has at least one evidence entry.
    var isRoomCurrentlyDocumented: Bool {
        guard let room else { return false }
        return !room.evidence.isEmpty
    }

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EvidenceCaptureHero(
                        roomName: roomName,
                        room: room,
                        existingEntries: existingEntries,
                        roomID: roomID,
                        selectedCondition: selectedCondition,
                        loadedImages: loadedImages,
                        loadedImageCount: loadedImages.count,
                        moveOutMode: moveOutMode
                    )
                    .padding(.bottom, 16)

                    EvidenceCaptureMediaModule(
                        selectedItems: $selectedItems,
                        onOpenCamera: { presentCameraIfAllowed() },
                        loadedImages: loadedImages,
                        isUploading: isUploading,
                        moveOutMode: moveOutMode
                    )
                    .padding(.bottom, 18)

                    EvidenceCaptureForm(
                        title: $title,
                        notes: $notes,
                        selectedTags: $selectedTags,
                        selectedCondition: $selectedCondition,
                        selectedItems: $selectedItems,
                        loadedImages: loadedImages,
                        isUploading: isUploading,
                        errorMessage: errorMessage,
                        successMessage: successMessage,
                        moveOutMode: moveOutMode,
                        fixedIssueTags: fixedIssueTags,
                        onRetry: { saveEvidence() }
                    )
                    .padding(.bottom, 18)

                    EvidenceSavedProofSection(
                        existingEntries: existingEntries,
                        moveOutMode: moveOutMode,
                        inspectionRepo: inspectionRepo,
                        onEdit: { editingEntry = $0 },
                        onAddPhotos: { appendPhotosEntry = $0 },
                        onDelete: { deleteConfirmEntry = $0 }
                    )
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 22)
                .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
            }
        }
        .safeAreaInset(edge: .bottom) {
            EvidenceCaptureBottomSaveBar(
                photoCount: loadedImages.count,
                tagCount: selectedTags.count,
                condition: selectedCondition,
                isUploading: isUploading,
                didJustSave: didJustSave,
                moveOutMode: moveOutMode,
                onSave: { saveEvidence() }
            )
        }
        .onChange(of: selectedItems) { _, newItems in
            loadSelectedItems(newItems)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(
                onCapture: { image in
                    loadedImages.append(downsample(image, maxDimension: 1200))
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
                onAdd: { photoData in
                    await appendPhotos(to: entry.id, photoData: photoData)
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
        .toolbar(.hidden, for: .tabBar)
        .mmProofToast(message: proofToast, isVisible: proofToastVisible)
        .onAppear {
            wasDocumentedOnLoad = isRoomCurrentlyDocumented
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
                                        .background(MoveMarkTheme.Colors.surfaceInset.opacity(0.65))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.42), lineWidth: 0.8)
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
                                        .fill(MoveMarkTheme.Colors.surfaceInset.opacity(0.55))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.38), lineWidth: 0.8)
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
            .background(MoveMarkTheme.Colors.background.ignoresSafeArea())
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
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))

                Text(
                    selectedTags.isEmpty
                        ? "Optional damage markers"
                        : "\(selectedTags.count) selected"
                )
                .font(.system(size: 12, weight: .medium))
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
                .font(.system(size: 13, weight: .medium))
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
                                : MoveMarkTheme.Colors.mint.opacity(0.5)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? MoveMarkTheme.Colors.primary.opacity(0.45)
                                : MoveMarkTheme.Colors.panelStroke,
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text("Updates this saved proof entry.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
            }

            Spacer(minLength: 0)

            Button {
                Task { await commitSave() }
            } label: {
                Text(isSaving ? "Saving…" : "Save changes")
                    .font(.system(size: 13.5, weight: .semibold))
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
        .background(MoveMarkTheme.Colors.panel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.panelStroke)
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
    let onAdd: ([Data]) async -> String?
    let onDismiss: () -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var isUploading = false
    @State private var localError: String?

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
                                        .background(MoveMarkTheme.Colors.surfaceInset.opacity(0.55))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.38), lineWidth: 0.8)
                                        )
                                }
                            }

                            PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .images) {
                                HStack(spacing: 10) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(loadedImages.isEmpty ? "Choose photos from library" : "\(loadedImages.count) new photo\(loadedImages.count == 1 ? "" : "s") selected")
                                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                                }
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(MoveMarkTheme.Colors.fieldFill.opacity(0.88))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.65), lineWidth: 0.9)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .disabled(isUploading)
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
                                        .background(MoveMarkTheme.Colors.surfaceInset.opacity(0.65))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.4), lineWidth: 0.8)
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
            .background(MoveMarkTheme.Colors.background.ignoresSafeArea())
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(bottomPrimaryColor)

                Text("Appends to this entry’s gallery.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
            }

            Spacer(minLength: 0)

            Button {
                Task { await commitAppend() }
            } label: {
                Text(isUploading ? "Adding…" : "Add to entry")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(loadedImages.isEmpty ? MoveMarkTheme.Colors.textSecondary : MoveMarkTheme.Colors.textOnPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(
                        Capsule()
                            .fill(
                                loadedImages.isEmpty
                                    ? MoveMarkTheme.Colors.mint.opacity(0.6)
                                    : MoveMarkTheme.Colors.primary.opacity(isUploading ? 0.72 : 1.0)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(loadedImages.isEmpty || isUploading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(MoveMarkTheme.Colors.panel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.panelStroke)
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
        localError = nil
        let data = loadedImages.compactMap { $0.jpegData(compressionQuality: 0.82) }
        guard !data.isEmpty else {
            MMHaptics.warning()
            localError = "Choose at least one photo to add."
            return
        }

        isUploading = true
        let err = await onAdd(data)
        isUploading = false

        if let err {
            localError = err
        } else {
            onDismiss()
        }
    }

    private func loadItems(_ items: [PhotosPickerItem]) {
        Task { @MainActor in
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let maxDim: CGFloat = 1200
                    let scale = min(maxDim / max(image.size.width, image.size.height), 1.0)
                    if scale < 1.0 {
                        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                        let renderer = UIGraphicsImageRenderer(size: newSize)
                        images.append(renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) })
                    } else {
                        images.append(image)
                    }
                }
            }
            loadedImages = images
            localError = nil
        }
    }
}
