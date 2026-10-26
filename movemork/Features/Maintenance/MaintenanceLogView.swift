//
//  MaintenanceLogView.swift
//  movemork
//
//  MoveMark — Maintenance log: issues first, then the inline composer (native PhotosPicker).
//

import SwiftUI
import PhotosUI

struct MaintenanceLogView: View {
    @Binding var path: [AppRoute]
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var title = ""
    @State private var selectedCategory: MaintenanceCategory = .other
    @State private var details = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    /// Source evidence for each pending photo (index-aligned with the `loadedImages` previews).
    @State private var loadedSources: [MMEvidenceSource] = []
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var errorRetryAction: (() -> Void)? = nil
    @State private var softNotice: String? = nil

    private var log: [MaintenanceRecord] {
        propertyStore.maintenanceLog
    }

    private var openIssues: [MaintenanceRecord] {
        log.filter { $0.status != .resolved }
    }

    private var resolvedIssues: [MaintenanceRecord] {
        log.filter { $0.status == .resolved }
    }

    init(path: Binding<[AppRoute]>, initialError: String? = nil, initialNotice: String? = nil, initiallyLoading: Bool = false) {
        _path = path
        _errorMessage = State(initialValue: initialError)
        _softNotice = State(initialValue: initialNotice)
        _isLoading = State(initialValue: initiallyLoading)
    }

    var body: some View {
        MMScreen(
            eyebrow: propertyStore.currentProperty.map { $0.title.isEmpty ? $0.addressLine1 : $0.title },
            title: "Maintenance",
            subtitle: "Log what breaks, with photos and dates. Each issue stays in your rental's record.",
            isPushed: true
        ) {
            if let errorMessage {
                MMNotice(
                    message: errorMessage,
                    actionTitle: errorRetryAction != nil ? MMCopy.tryAgain : nil,
                    action: errorRetryAction
                )
                .padding(.bottom, 18)
            } else if let softNotice {
                MMNotice(message: softNotice, tone: .info).padding(.bottom, 18)
            }

            issueList

            composer
                .padding(.top, log.isEmpty && !isLoading ? 22 : 30)
        }
        // Re-sync when the active vault changes; list reads `propertyStore.maintenanceLog` (hydrated on switch + refreshed here).
        .task(id: propertyStore.currentProperty?.id) { await syncMaintenanceLogFromServer() }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var issueList: some View {
        if log.isEmpty && isLoading {
            HStack(spacing: 10) {
                ProgressView().tint(MMInk.secondary)
                Text("Loading issues…").mmFont(14).foregroundStyle(MMInk.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .accessibilityElement(children: .combine)
        } else if log.isEmpty {
            MMEmptyBlock(
                icon: "wrench.and.screwdriver",
                title: "No issues logged yet",
                message: "When something breaks or needs your landlord, log it below with photos. Dated issues become part of your record."
            )
        } else {
            VStack(alignment: .leading, spacing: 26) {
                issueSection(title: "Open", rows: openIssues)
                issueSection(title: "Resolved", rows: resolvedIssues)
            }
            if isLoading {
                ProgressView().tint(MMInk.secondary).frame(maxWidth: .infinity).padding(.top, 14)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 0) {
            MMSectionTitle(title: "Log an issue")
            Text("Add it while it's fresh. Photos and timestamps matter.")
                .mmFont(14)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 14) {
                MMField(title: "Issue title", placeholder: "Bathroom leak", text: $title)
                categoryPicker
                MMField(title: "Details", placeholder: "What happened, where, and what was reported", text: $details, axis: .vertical)
            }
            .padding(.top, 16)

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
            .padding(.top, 16)

            MMPrimaryButton(title: "Save issue", isLoading: isSubmitting, isDisabled: isSubmitting) { addIncident() }
                .padding(.top, 22)
        }
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

    @ViewBuilder
    private func issueSection(title: String, rows: [MaintenanceRecord]) -> some View {
        if !rows.isEmpty {
            MMGroup(title: "\(title) · \(rows.count)") {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { MMRowDivider() }
                    Button {
                        path.append(.maintenanceIssueDetail(issueID: entry.id))
                    } label: {
                        issueRow(entry)
                    }
                    .buttonStyle(MMLightPressStyle())
                }
            }
        }
    }

    private func issueRow(_ entry: MaintenanceRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .mmFont(16, .medium)
                    .foregroundStyle(MMInk.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(maintenanceMetadataLine(for: entry))
                    .mmFont(13)
                    .foregroundStyle(MMInk.secondary)
                if !entry.details.isEmpty {
                    Text(entry.details)
                        .mmFont(14)
                        .foregroundStyle(MMInk.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                MMStatusLabel(text: entry.status.rawValue, tone: entry.status == .resolved ? .done : .open)
                    .padding(.top, 4)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MMInk.secondary.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func maintenanceMetadataLine(for entry: MaintenanceRecord) -> String {
        let date = entry.createdAt.formatted(date: .abbreviated, time: .omitted)
        if entry.photoCount > 0 {
            return "\(entry.category) · \(entry.photoCount) photo\(entry.photoCount == 1 ? "" : "s") · \(date)"
        }
        return "\(entry.category) · \(date)"
    }

    private func syncMaintenanceLogFromServer() async {
        guard let property = propertyStore.currentProperty else { return }
        isLoading = true
        errorMessage = nil
        errorRetryAction = nil
        defer { isLoading = false }

        let ok = await propertyStore.refreshMaintenance(propertyId: property.id)
        if !ok {
            errorMessage = MoveMarkFlowMessage.maintenanceListSyncFailed
            errorRetryAction = { Task { await syncMaintenanceLogFromServer() } }
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
        softNotice = nil

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

                title = ""
                selectedCategory = .other
                details = ""
                selectedPhotos = []
                loadedImages = []
                loadedSources = []

                if outcome.hadPartialPhotoLoss && outcome.listRefreshFailed {
                    softNotice =
                        "\(MoveMarkFlowMessage.maintenancePartialPhotosSaved) If the list looks wrong, open Maintenance again."
                } else if outcome.hadPartialPhotoLoss {
                    softNotice = MoveMarkFlowMessage.maintenancePartialPhotosSaved
                } else if outcome.listRefreshFailed {
                    softNotice = MoveMarkFlowMessage.incidentSavedRefreshStale
                }
                MMHaptics.success()
            } catch {
                errorMessage = MoveMarkFlowMessage.maintenanceComposerFailed(error)
                errorRetryAction = { addIncident() }
                MMHaptics.error()
            }
        }
    }
}
