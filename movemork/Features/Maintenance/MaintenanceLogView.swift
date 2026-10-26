//
//  MaintenanceLogView.swift
//  movemork
//
//  MoveMark — maintenance cases as evidence-first case files.
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
    @State private var isShowingComposer = false
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
            MoveMarkTheme.Colors.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.sectionGap) {
                    header

                    if let softNotice, errorMessage == nil {
                        quietNotice(softNotice)
                    }

                    if let errorMessage {
                        MMErrorBanner(
                            message: errorMessage,
                            retryTitle: errorRetryAction != nil ? MMCopy.tryAgain : nil,
                            onRetry: errorRetryAction
                        )
                    }

                    if isLoading && log.isEmpty {
                        ProgressView()
                            .tint(MoveMarkTheme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                    } else if log.isEmpty {
                        emptyState
                    } else {
                        if let active = openIssues.first {
                            activeCase(active)
                        }

                        if openIssues.count > 1 {
                            issueListSection(
                                title: "Other open cases",
                                subtitle: "Still waiting on proof, response, or resolution.",
                                rows: Array(openIssues.dropFirst())
                            )
                        }

                        if !resolvedIssues.isEmpty {
                            issueListSection(
                                title: "Resolved",
                                subtitle: "Closed incidents stay preserved in your record.",
                                rows: resolvedIssues
                            )
                        }
                    }

                    MMButton(
                        title: "Log incident",
                        action: {
                            MMHaptics.soft()
                            isShowingComposer = true
                        },
                        kind: .primary
                    )
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 22)
                .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
            }
        }
        .task(id: propertyStore.currentProperty?.id) { await syncMaintenanceLogFromServer() }
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingComposer) {
            composerSheet
                .presentationDragIndicator(.visible)
                .presentationBackground(MoveMarkTheme.Colors.appBackground)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MAINTENANCE RECORD")
                .font(MoveMarkTheme.Typography.sectionLabel)
                .tracking(0.9)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

            Text("Keep the issue, response, and proof together.")
                .font(MoveMarkTheme.Typography.pageTitle)
                .tracking(-0.8)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("A maintenance case should read like a timeline later: what happened, when you reported it, what changed, and what evidence you kept.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 22) {
                metric(value: openIssues.count, label: "Open")
                metric(value: resolvedIssues.count, label: "Resolved")
            }
            .padding(.top, 4)
        }
    }

    private func metric(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(MoveMarkTheme.Typography.cardValue)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(label)
                .font(MoveMarkTheme.Typography.metadata)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            MMSectionLabel("Cases")

            MMEmptyState(
                systemImage: "wrench.and.screwdriver",
                title: "No maintenance cases yet",
                message: "When something breaks or needs landlord follow-up, record it here with dated photos and notes."
            )
        }
    }

    private func activeCase(_ entry: MaintenanceRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MMSectionLabel("Active case") {
                Text("OPEN")
                    .font(MoveMarkTheme.Typography.sectionLabel)
                    .tracking(0.8)
                    .foregroundStyle(MoveMarkTheme.Colors.semanticWarning)
            }

            Button {
                path.append(.maintenanceIssueDetail(issueID: entry.id))
            } label: {
                ProofCaseCard(contentPadding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.title)
                                    .font(MoveMarkTheme.Typography.heroTitle)
                                    .tracking(-0.5)
                                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(maintenanceMetadataLine(for: entry))
                                    .font(MoveMarkTheme.Typography.metadata)
                                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            }

                            Spacer(minLength: 8)

                            MMPill(text: entry.category, tone: .warning)
                        }

                        if !entry.details.isEmpty {
                            Text(entry.details)
                                .font(MoveMarkTheme.Typography.body)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(4)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(MoveMarkTheme.Typography.metadata)
                            Text("Open case record")
                                .font(MoveMarkTheme.Typography.subheadlineMedium)
                        }
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the maintenance case timeline and evidence.")
        }
    }

    private func issueListSection(
        title: String,
        subtitle: String,
        rows: [MaintenanceRecord]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MMProofSectionHeader(title: title, subtitle: subtitle)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        path.append(.maintenanceIssueDetail(issueID: entry.id))
                    } label: {
                        maintenanceRow(entry)
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Divider()
                            .overlay(MoveMarkTheme.Stroke.normal)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.card, style: .continuous)
                    .fill(MoveMarkTheme.Surface.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.card, style: .continuous)
                    .stroke(MoveMarkTheme.Stroke.normal, lineWidth: 1)
            )
        }
    }

    private func maintenanceRow(_ entry: MaintenanceRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.title)
                    .font(MoveMarkTheme.Typography.rowTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(maintenanceMetadataLine(for: entry))
                    .font(MoveMarkTheme.Typography.metadata)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                MMPill(
                    text: entry.status.rawValue,
                    tone: entry.status == .resolved ? .success : .warning
                )

                Image(systemName: "chevron.right")
                    .font(MoveMarkTheme.Typography.metadata)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
        }
        .padding(.vertical, MoveMarkTheme.Spacing.rowVertical)
        .contentShape(Rectangle())
    }

    private var composerSheet: some View {
        NavigationStack {
            ZStack {
                MoveMarkTheme.Colors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LOG INCIDENT")
                                .font(MoveMarkTheme.Typography.sectionLabel)
                                .tracking(0.9)
                                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

                            Text("Record it while it’s fresh.")
                                .font(MoveMarkTheme.Typography.heroTitle)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                            Text("Add what happened, where it happened, and any photos that preserve the condition.")
                                .font(MoveMarkTheme.Typography.body)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            MMTextField(title: "Issue title", placeholder: "Bathroom leak", text: $title)
                            categoryPicker
                            MMTextField(
                                title: "Details",
                                placeholder: "What happened, where, and what was reported",
                                text: $details
                            )
                        }

                        photoPicker

                        if let errorMessage {
                            MMErrorBanner(
                                message: errorMessage,
                                retryTitle: errorRetryAction != nil ? MMCopy.tryAgain : nil,
                                onRetry: errorRetryAction
                            )
                        }

                        ZStack {
                            MMButton(
                                title: "Save incident",
                                action: { addIncident() },
                                kind: .primary,
                                isDisabled: isSubmitting
                            )
                            .opacity(isSubmitting ? 0.6 : 1)

                            if isSubmitting {
                                ProgressView()
                                    .tint(MoveMarkTheme.Colors.textOnPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("New case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if !isSubmitting {
                            resetComposer()
                            isShowingComposer = false
                        }
                    }
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }
        }
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            MMSectionLabel("Evidence")

            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images,
                preferredItemEncoding: .current
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(loadedImages.isEmpty ? "Attach photos" : "\(loadedImages.count) photo\(loadedImages.count == 1 ? "" : "s") selected")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                    Spacer()
                    Image(systemName: "plus")
                }
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(MoveMarkTheme.Surface.interactive)
                .clipShape(RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.row, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.row, style: .continuous)
                        .stroke(MoveMarkTheme.Stroke.interactive, lineWidth: 1)
                )
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
                                .frame(width: 82, height: 82)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
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

    private func quietNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Text(message)
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.row, style: .continuous)
                .fill(MoveMarkTheme.Surface.raised)
        )
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
            let selection = await MMEvidencePicker.load(items)
            loadedSources = selection.sources
            loadedImages = selection.previews
            if let message = selection.rejectionMessage {
                errorMessage = message
            }
        }
    }

    private func resetComposer() {
        title = ""
        selectedCategory = .other
        details = ""
        selectedPhotos = []
        loadedImages = []
        loadedSources = []
        errorMessage = nil
        errorRetryAction = nil
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

                resetComposer()
                isShowingComposer = false

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
