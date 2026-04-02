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
                        showCamera: $showCamera,
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
                        showCamera: $showCamera,
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
                    Task {
                        await saveEditedEvidence(entryId: entry.id, title: title, notes: notes, tags: tags, condition: condition)
                    }
                    editingEntry = nil
                },
                onDismiss: { editingEntry = nil }
            )
        }
        .sheet(item: $appendPhotosEntry) { entry in
            AppendPhotosSheet(
                entry: entry,
                onAdd: { photoData in
                    Task {
                        await appendPhotos(to: entry.id, photoData: photoData)
                    }
                    appendPhotosEntry = nil
                },
                onDismiss: { appendPhotosEntry = nil }
            )
        }
        .confirmationDialog("Delete this proof entry?", isPresented: Binding(get: { deleteConfirmEntry != nil }, set: { if !$0 { deleteConfirmEntry = nil } })) {
            Button("Delete", role: .destructive) {
                if let entry = deleteConfirmEntry {
                    Task { await deleteEntry(entry.id) }
                }
                deleteConfirmEntry = nil
            }
            Button("Cancel", role: .cancel) {
                deleteConfirmEntry = nil
            }
        } message: {
            Text("Photos and notes for this entry will be removed. This cannot be undone.")
        }
        .navigationTitle(roomName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            wasDocumentedOnLoad = isRoomCurrentlyDocumented
        }
    }

}

// MARK: - Edit evidence sheet
private struct EditEvidenceSheet: View {
    let evidence: EvidenceRecord
    let roomName: String
    let onSave: (String, String, [String], RoomRecord.ConditionRating) -> Void
    let onDismiss: () -> Void

    @State private var title: String
    @State private var notes: String
    @State private var selectedTags: Set<String>
    @State private var condition: RoomRecord.ConditionRating

    init(evidence: EvidenceRecord, roomName: String, onSave: @escaping (String, String, [String], RoomRecord.ConditionRating) -> Void, onDismiss: @escaping () -> Void) {
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
                VStack(alignment: .leading, spacing: 16) {
                    MMTextField(title: "Title", placeholder: "e.g. North wall", text: $title)
                    MMTextField(title: "Notes", placeholder: "Details", text: $notes)
                    tagPicker
                    Picker("Condition", selection: $condition) {
                        ForEach(RoomRecord.ConditionRating.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            title.isEmpty ? roomName : title,
                            notes,
                            Array(selectedTags),
                            condition
                        )
                    }
                }
            }
        }
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Issue tags")
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            FlowLayout(spacing: 8) {
                ForEach(fixedIssueTags, id: \.self) { tag in
                    Button {
                        if selectedTags.contains(tag) { selectedTags.remove(tag) }
                        else { selectedTags.insert(tag) }
                    } label: {
                        MMPill(text: tag, tone: selectedTags.contains(tag) ? .warning : .neutral)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Append photos sheet
private struct AppendPhotosSheet: View {
    let entry: EvidenceRecord
    let onAdd: ([Data]) -> Void
    let onDismiss: () -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var isUploading = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add photos to \"\(entry.title)\"")
                    .font(MoveMarkTheme.Typography.sectionTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .images) {
                    Text(loadedImages.isEmpty ? "Select photos" : "\(loadedImages.count) photos selected")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(MoveMarkTheme.Colors.fieldFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(isUploading)
                .onChange(of: selectedItems) { _, new in
                    loadItems(new)
                }

                if !loadedImages.isEmpty {
                    Text("\(loadedImages.count) photo(s) will be added to this entry.")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }
            .padding()
            .navigationTitle("Add photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let data = loadedImages.compactMap { $0.jpegData(compressionQuality: 0.82) }
                        if !data.isEmpty {
                            isUploading = true
                            onAdd(data)
                        } else {
                            onDismiss()
                        }
                    }
                    .disabled(loadedImages.isEmpty || isUploading)
                }
            }
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
        }
    }
}
