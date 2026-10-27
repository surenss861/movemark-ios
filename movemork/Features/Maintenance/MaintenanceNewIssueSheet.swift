//
//  MaintenanceNewIssueSheet.swift
//  movemork
//
//  MoveMark — Record an issue: the focused surface opened from the Maintenance log's "+" (and its empty state).
//  Title, category, details, photos (native PhotosPicker), one lime Save. Saving creates the case exactly as the
//  log's composer did, then dismisses; the new case appears in the log.
//

import SwiftUI
import PhotosUI

struct MaintenanceNewIssueSheet: View {
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    /// Called after a successful save with an optional calm notice for the log (partial photos, stale list).
    let onSaved: (String?) -> Void
    let onCancel: () -> Void

    @State private var title = ""
    @State private var selectedCategory: MaintenanceCategory = .other
    @State private var details = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    /// Source evidence for each pending photo (index-aligned with the `loadedImages` previews).
    @State private var loadedSources: [MMEvidenceSource] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var errorRetryAction: (() -> Void)? = nil

    init(initialError: String? = nil, onSaved: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
        self.onSaved = onSaved
        self.onCancel = onCancel
        _errorMessage = State(initialValue: initialError)
    }

    var body: some View {
        MMSheetScaffold(title: "Record an issue") {
            if let errorMessage {
                MMNotice(
                    message: errorMessage,
                    actionTitle: errorRetryAction != nil ? MMCopy.tryAgain : nil,
                    action: errorRetryAction
                )
                .padding(.bottom, 16)
            }

            VStack(alignment: .leading, spacing: 16) {
                MMField(title: "Issue title", placeholder: "Water leak under sink", text: $title)
                categoryPicker
                MMField(title: "Details", placeholder: "What happened, where, and what was reported", text: $details, axis: .vertical)
            }

            MMGroup {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images,
                    preferredItemEncoding: .current
                ) {
                    MMPhotoPickerLabel(
                        title: loadedImages.isEmpty ? "Attach photos" : "\(loadedImages.count) photo\(loadedImages.count == 1 ? "" : "s") selected",
                        icon: "camera"
                    )
                }
                .buttonStyle(MMLightPressStyle())
                .onChange(of: selectedPhotos) { _, newItems in
                    loadPhotos(newItems)
                }

                if !loadedImages.isEmpty {
                    MMRowDivider()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(loadedImages.indices, id: \.self) { index in
                                Image(uiImage: loadedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .padding(.top, 18)

            Text("MoveMark dates the case when you save it and keeps the photos with it.")
                .mmFont(12.5)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .padding(.horizontal, 4)

            MMPrimaryButton(title: "Save issue", isLoading: isSubmitting, isDisabled: isSubmitting) { addIncident() }
                .padding(.top, 22)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel).disabled(isSubmitting)
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category").mmFont(13, .medium).foregroundStyle(MMInk.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MaintenanceCategory.allCases, id: \.self) { cat in
                        MMChip(title: cat.rawValue, isSelected: selectedCategory == cat) {
                            selectedCategory = cat
                        }
                        .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        Task { @MainActor in
            let selection = await MMEvidencePicker.load(items)
            loadedSources = selection.sources
            loadedImages = selection.previews
            if let message = selection.rejectionMessage {
                errorMessage = message
            }
        }
    }

    private func addIncident() {
        guard let property = propertyStore.currentProperty,
              let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.noPropertyOrAuth
            return
        }

        guard !isSubmitting else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            errorMessage = "Enter an issue title."
            return
        }

        isSubmitting = true
        errorMessage = nil
        errorRetryAction = nil

        let record = MaintenanceRecord(
            title: trimmedTitle,
            category: selectedCategory.rawValue,
            details: details,
            status: .open,
            landlordResponse: "",
            photoCount: loadedImages.count
        )

        let photoData = loadedSources

        Task { @MainActor in
            defer { isSubmitting = false }

            do {
                let outcome = try await propertyStore.addMaintenance(
                    record,
                    photos: photoData,
                    propertyId: property.id,
                    userId: userId
                )

                var notice: String? = nil
                if outcome.hadPartialPhotoLoss && outcome.listRefreshFailed {
                    notice = "\(MoveMarkFlowMessage.maintenancePartialPhotosSaved) If the list looks wrong, open Maintenance again."
                } else if outcome.hadPartialPhotoLoss {
                    notice = MoveMarkFlowMessage.maintenancePartialPhotosSaved
                } else if outcome.listRefreshFailed {
                    notice = MoveMarkFlowMessage.incidentSavedRefreshStale
                }
                MMHaptics.success()
                onSaved(notice)
            } catch {
                errorMessage = MoveMarkFlowMessage.maintenanceComposerFailed(error)
                errorRetryAction = { addIncident() }
                MMHaptics.error()
            }
        }
    }
}
