//
//  MaintenanceIssueDetailView.swift
//  movemork
//
//  MoveMark — Issue detail with timeline, evidence, follow-up, resolve.
//

import SwiftUI
import PhotosUI
import NukeUI

struct MaintenanceIssueDetailView: View {
    @Environment(PropertyStore.self) private var propertyStore

    @State private var issue: MaintenanceIssueRow
    @State private var followUpNote = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isSavingFollowUp = false
    @State private var isUploadingPhotos = false
    @State private var evidenceURLs: [URL] = []
    @State private var evidenceFileCount = 0
    @State private var isLoadingEvidence = false
    @State private var errorMessage: String? = nil
    @State private var softNotice: String? = nil
    @State private var retryAction: (() -> Void)? = nil
    @State private var isResolving = false

    private let inspectionRepo = InspectionRepository()
    private let maintenanceRepo = MaintenanceRepository()

    init(issue: MaintenanceIssueRow) {
        _issue = State(initialValue: issue)
    }

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    overviewCard

                    timelineCard

                    if evidenceFileCount > 0 {
                        evidenceCard
                    }

                    followUpCard

                    resolveCard

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
                            retryTitle: retryAction != nil ? MMCopy.tryAgain : nil,
                            onRetry: retryAction
                        )
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 22)
                .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
            }
        }
        .task { await loadEvidence() }
        .onChange(of: selectedPhotos) { _, newItems in
            uploadPhotos(newItems)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(issue.title)
                .font(MoveMarkTheme.Typography.screenTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text("Issue detail, timeline, and supporting evidence.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Rectangle()
                .fill(MoveMarkTheme.Colors.accent)
                .frame(width: 38, height: 3)
                .clipShape(Capsule())
        }
    }

    private var overviewCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    MMPill(text: issue.category ?? "General", tone: .warning)
                    Spacer()
                    MMPill(text: issue.status, tone: issue.status == "resolved" ? .success : .warning)
                }

                if let description = issue.description, !description.isEmpty {
                    Text(description)
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                detailRow("Discovered", formatted(issue.dateDiscovered))
                detailRow("Reported", formatted(issue.dateReported))
                detailRow("Response", issue.landlordResponse ?? "No response recorded")
                detailRow("Follow-up", formatted(issue.followUpDate))
            }
        }
    }

    private var timelineCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Timeline")

                TimelineRow(title: "Discovered", value: formatted(issue.dateDiscovered), isEmphasized: true)
                TimelineRow(title: "Reported", value: formatted(issue.dateReported))
                TimelineRow(title: "Response", value: issue.landlordResponse ?? "Pending")
                TimelineRow(title: "Follow-up", value: formatted(issue.followUpDate))
            }
        }
    }

    private var evidenceCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Evidence")

                if isLoadingEvidence {
                    ProgressView()
                        .tint(MoveMarkTheme.Colors.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if evidenceURLs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Couldn’t load photo previews. Your files may still be saved.")
                            .font(MoveMarkTheme.Typography.subheadline)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        MMButton(
                            title: "Retry previews",
                            action: { Task { await loadEvidence() } },
                            kind: .secondary,
                            size: .compact,
                            expandsToFillWidth: false
                        )
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(evidenceURLs, id: \.absoluteString) { url in
                                MaintenanceEvidenceThumbnail(url: url, propertyId: issue.propertyId) {
                                    Task { await loadEvidence() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var followUpCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Follow-up")

                MMTextField(
                    title: "Landlord response / follow-up note",
                    placeholder: "Add what happened next, what they said, or what you sent",
                    text: $followUpNote
                )

                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "paperclip")
                        Text(isUploadingPhotos ? "Uploading..." : "Attach more photos")
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
                .disabled(isUploadingPhotos)

                ZStack {
                    MMButton(title: "Save follow-up", action: saveFollowUp, isDisabled: isSavingFollowUp)
                        .opacity(isSavingFollowUp ? 0.6 : 1.0)

                    if isSavingFollowUp {
                        ProgressView().tint(MoveMarkTheme.Colors.primary)
                    }
                }
            }
        }
    }

    private var resolveCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Status")

                Text(issue.status == "resolved"
                     ? "This incident is marked resolved and stays in the record."
                     : "Mark this incident resolved once it's closed. The proof remains preserved.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                if issue.status != "resolved" {
                    ZStack {
                        MMButton(title: "Mark resolved", action: markResolved, isSecondary: true, isDisabled: isResolving)
                            .opacity(isResolving ? 0.6 : 1.0)

                        if isResolving {
                            ProgressView().tint(MoveMarkTheme.Colors.primary)
                        }
                    }
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatted(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "Not recorded" }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        }
        return value
    }

    private func loadEvidence() async {
        softNotice = nil
        isLoadingEvidence = true
        defer { isLoadingEvidence = false }
        do {
            let files = try await inspectionRepo.fetchEvidenceFilesByMaintenanceIssue(issueId: issue.id)
            evidenceFileCount = files.count
            guard !files.isEmpty else {
                evidenceURLs = []
                return
            }
            evidenceURLs = try await fetchEvidencePreviewURLs(files: files)
        } catch {
            errorMessage = MoveMarkFlowMessage.maintenanceEvidenceLoadFailed(error)
            retryAction = { Task { await loadEvidence() } }
        }
    }

    private func fetchEvidencePreviewURLs(files: [EvidenceFileRow]) async throws -> [URL] {
        var urls: [URL] = []
        var lastError: Error?
        for file in files {
            do {
                let u = try await inspectionRepo.signedURL(bucket: "maintenance-media", path: file.filePath)
                urls.append(u)
            } catch {
                lastError = error
            }
        }
        if urls.isEmpty, let lastError { throw lastError }
        return urls
    }

    /// Reload previews after upload; returns `false` if the list couldn’t be refreshed (photos may still be saved).
    private func reloadEvidencePreviewURLs() async -> Bool {
        do {
            let files = try await inspectionRepo.fetchEvidenceFilesByMaintenanceIssue(issueId: issue.id)
            evidenceFileCount = files.count
            guard !files.isEmpty else {
                evidenceURLs = []
                return true
            }
            evidenceURLs = try await fetchEvidencePreviewURLs(files: files)
            return true
        } catch {
            return false
        }
    }

    private func uploadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        isUploadingPhotos = true
        errorMessage = nil
        softNotice = nil
        retryAction = nil

        Task { @MainActor in
            defer { isUploadingPhotos = false }

            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let path = "\(issue.userId)/\(issue.propertyId)/\(issue.id)/\(UUID().uuidString).jpg"
                do {
                    _ = try await maintenanceRepo.uploadAttachment(data: data, path: path)
                } catch {
                    errorMessage = MoveMarkFlowMessage.maintenancePhotoUploadFailed(error)
                    retryAction = { uploadPhotos(items) }
                    return
                }
                do {
                    try await inspectionRepo.insertEvidenceFile(
                        propertyId: issue.propertyId,
                        inspectionItemId: nil,
                        maintenanceIssueId: issue.id,
                        filePath: path,
                        fileType: "image",
                        capturedAt: Date()
                    )
                } catch {
                    await maintenanceRepo.removeOrphanUploadedAttachment(path: path)
                    errorMessage = MoveMarkFlowMessage.maintenancePhotoRecordFailed(error)
                    retryAction = { uploadPhotos(items) }
                    return
                }
            }
            selectedPhotos = []
            let previewsOK = await reloadEvidencePreviewURLs()
            if !previewsOK {
                softNotice = MoveMarkFlowMessage.maintenanceEvidencePreviewHint
            }
        }
    }

    private func saveFollowUp() {
        guard !isSavingFollowUp else { return }

        isSavingFollowUp = true
        errorMessage = nil
        retryAction = nil

        Task { @MainActor in
            defer { isSavingFollowUp = false }

            do {
                try await maintenanceRepo.updateFollowUp(id: issue.id, note: followUpNote)
                var updated = issue
                updated.landlordResponse = followUpNote
                updated.followUpDate = ISO8601DateFormatter().string(from: Date())
                issue = updated
                followUpNote = ""
                _ = await propertyStore.refreshMaintenance(propertyId: issue.propertyId)
            } catch {
                errorMessage = MoveMarkFlowMessage.maintenanceFollowUpFailed(error)
                retryAction = { saveFollowUp() }
            }
        }
    }

    private func markResolved() {
        guard !isResolving else { return }

        isResolving = true
        errorMessage = nil
        retryAction = nil

        Task { @MainActor in
            defer { isResolving = false }

            do {
                try await maintenanceRepo.markResolved(id: issue.id)
                var updated = issue
                updated.status = "resolved"
                issue = updated
                MMHaptics.success()
                _ = await propertyStore.refreshMaintenance(propertyId: issue.propertyId)
            } catch {
                errorMessage = MoveMarkFlowMessage.maintenanceResolveFailed(error)
                retryAction = { markResolved() }
            }
        }
    }
}

// MARK: - Maintenance evidence thumbnail (signed URL / Nuke retry)

private struct MaintenanceEvidenceThumbnail: View {
    let url: URL
    let propertyId: UUID
    let onSignedURLExpired: () -> Void

    var body: some View {
        LazyImage(url: url, resizingMode: .aspectFill)
            .onFailure { _ in
                Task {
                    await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)
                    await MainActor.run { onSignedURLExpired() }
                }
            }
            .frame(width: 120, height: 120)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
