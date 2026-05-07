//
//  MaintenanceLogView.swift
//  movemork
//
//  MoveMark — Maintenance log with premium proof-first layout.
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

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    composerCard

                    if let softNotice, errorMessage == nil {
                        MMCard(tone: .quiet, padding: 14, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.9))
                                Text(softNotice)
                                    .font(MoveMarkTheme.Typography.subheadline)
                                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            }
                        }
                    }

                    if let errorMessage {
                        MMErrorBanner(
                            message: errorMessage,
                            retryTitle: errorRetryAction != nil ? MMCopy.tryAgain : nil,
                            onRetry: errorRetryAction
                        )
                    }

                    if log.isEmpty && !isLoading {
                        MMEmptyState(
                            systemImage: "wrench.and.screwdriver",
                            title: "No maintenance issues logged yet",
                            message: "When something breaks or needs landlord follow-up, log it here with photos. Dated incidents become part of your vault record."
                        )
                    }

                    issueSection(
                        title: "Open incidents",
                        subtitle: "Current issues that still need proof, response, or resolution.",
                        rows: openIssues,
                        tone: .warning
                    )

                    issueSection(
                        title: "Resolved",
                        subtitle: "Closed issues preserved in the record.",
                        rows: resolvedIssues,
                        tone: .success
                    )

                    if isLoading {
                        ProgressView()
                            .tint(MoveMarkTheme.Colors.primary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 22)
                .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
            }
        }
        // Re-sync when the active vault changes; list reads `propertyStore.maintenanceLog` (hydrated on switch + refreshed here).
        .task(id: propertyStore.currentProperty?.id) { await syncMaintenanceLogFromServer() }
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Maintenance")
                .font(MoveMarkTheme.Typography.screenTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text("Track incidents, landlord follow-up, and supporting evidence as part of the record.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Rectangle()
                .fill(MoveMarkTheme.Colors.accent)
                .frame(width: 38, height: 3)
                .clipShape(Capsule())
        }
    }

    private var composerCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Log incident")

                Text("Add the issue while it's fresh. Photos and timestamps matter.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                MMTextField(title: "Issue title", placeholder: "Bathroom leak", text: $title)
                categoryPicker
                MMTextField(title: "Details", placeholder: "What happened, where, and what was reported", text: $details)

                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .semibold))

                        Text(loadedImages.isEmpty ? "Attach photos" : "\(loadedImages.count) photos selected")
                            .font(MoveMarkTheme.Typography.subheadlineMedium)
                    }
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(MoveMarkTheme.Colors.fieldFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .onChange(of: selectedPhotos) { _, newItems in
                    loadPhotos(newItems)
                }

                if !loadedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(loadedImages.indices, id: \.self) { index in
                                Image(uiImage: loadedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 68, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                }

                ZStack {
                    MMButton(
                        title: "Save incident",
                        action: { addIncident() },
                        isDisabled: isSubmitting
                    )
                    .opacity(isSubmitting ? 0.6 : 1.0)

                    if isSubmitting {
                        ProgressView().tint(MoveMarkTheme.Colors.primary)
                    }
                }
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MaintenanceCategory.allCases, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            MMPill(
                                text: cat.rawValue,
                                tone: selectedCategory == cat ? .warning : .neutral
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func issueSection(title: String, subtitle: String, rows: [MaintenanceRecord], tone: MMPill.Tone) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    MMSectionHeader(title: title, subtitle: subtitle)
                    Spacer()
                    MMPill(text: "\(rows.count)", tone: tone)
                }

                ForEach(rows) { entry in
                    Button {
                        path.append(.maintenanceIssueDetail(issueID: entry.id))
                    } label: {
                        MMCard(tone: .artifact) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(entry.title)
                                    .font(MoveMarkTheme.Typography.cardTitle)
                                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(maintenanceMetadataLine(for: entry))
                                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                                HStack {
                                    MMPill(text: entry.category, tone: .warning)
                                    Spacer()
                                    MMPill(
                                        text: entry.status.rawValue,
                                        tone: entry.status == .resolved ? .success : .warning
                                    )
                                }

                                if !entry.details.isEmpty {
                                    Text(entry.details)
                                        .font(MoveMarkTheme.Typography.subheadline)
                                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineLimit(3)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func maintenanceMetadataLine(for entry: MaintenanceRecord) -> String {
        let date = entry.createdAt.formatted(date: .abbreviated, time: .omitted)
        if entry.photoCount > 0 {
            return "\(entry.photoCount) photo\(entry.photoCount == 1 ? "" : "s") · \(date)"
        }
        return date
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
            var images: [UIImage] = []

            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let size = image.size
                    let scale = min(1200 / max(size.width, size.height), 1.0)

                    if scale < 1.0 {
                        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
                        let renderer = UIGraphicsImageRenderer(size: newSize)
                        images.append(renderer.image { _ in
                            image.draw(in: CGRect(origin: .zero, size: newSize))
                        })
                    } else {
                        images.append(image)
                    }
                }
            }

            loadedImages = images
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

        let photoData = loadedImages.compactMap { $0.jpegData(compressionQuality: 0.82) }

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
