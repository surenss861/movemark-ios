//
//  MaintenanceIssueDetailView.swift
//  movemork
//
//  MoveMark — maintenance issue as a preserved case timeline.
//

import SwiftUI
import PhotosUI

struct MaintenanceIssueDetailView: View {
    @Environment(PropertyStore.self) private var propertyStore

    @State private var issue: MaintenanceIssueRow
    @State private var followUpNote = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isSavingFollowUp = false
    @State private var isUploadingPhotos = false
    @State private var evidencePreviews: [MaintenanceEvidencePreview] = []
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
            MoveMarkTheme.Colors.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.sectionGap) {
                    caseHero

                    evidenceSection

                    timelineSection

                    followUpSection

                    statusSection

                    if let softNotice, errorMessage == nil {
                        quietNotice(softNotice)
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
                .padding(.top, 20)
                .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
            }
        }
        .task { await loadEvidence() }
        .onChange(of: selectedPhotos) { _, newItems in
            uploadPhotos(newItems)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var caseHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MAINTENANCE CASE")
                .font(MoveMarkTheme.Typography.sectionLabel)
                .tracking(0.9)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

            ProofCaseCard(contentPadding: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(issue.title)
                                .font(MoveMarkTheme.Typography.pageTitle)
                                .tracking(-0.8)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(formatted(issue.dateDiscovered))
                                .font(MoveMarkTheme.Typography.metadata)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        }

                        Spacer(minLength: 8)

                        MMPill(
                            text: issue.status,
                            tone: issue.status == "resolved" ? .success : .warning
                        )
                    }

                    HStack(spacing: 8) {
                        Text(issue.category ?? "General")
                            .font(MoveMarkTheme.Typography.subheadlineMedium)
                            .foregroundStyle(MoveMarkTheme.Colors.semanticWarning)

                        if evidenceFileCount > 0 {
                            Text("·")
                                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                            Text("\(evidenceFileCount) photo\(evidenceFileCount == 1 ? "" : "s")")
                                .font(MoveMarkTheme.Typography.subheadline)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        }
                    }

                    if let description = issue.description, !description.isEmpty {
                        Text(description)
                            .font(MoveMarkTheme.Typography.body)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMSectionLabel("Evidence") {
                if evidenceFileCount > 0 {
                    Text("\(evidenceFileCount)")
                        .font(MoveMarkTheme.Typography.metadata)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }

            if isLoadingEvidence {
                ProgressView()
                    .tint(MoveMarkTheme.Colors.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else if evidenceFileCount == 0 {
                Text("No photos attached yet. Add evidence when the condition changes or you receive a response.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if evidencePreviews.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Couldn’t load photo previews. Your files may still be preserved.")
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
                        ForEach(evidencePreviews) { preview in
                            MaintenanceEvidenceThumbnail(preview: preview, propertyId: issue.propertyId) {
                                Task { await loadEvidence() }
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMProofSectionHeader(
                title: "Timeline",
                subtitle: "A dated record of the issue and what happened next."
            )

            VStack(alignment: .leading, spacing: 0) {
                TimelineRow(title: "Discovered", value: formatted(issue.dateDiscovered), isEmphasized: true)
                TimelineRow(title: "Reported", value: formatted(issue.dateReported))
                TimelineRow(title: "Landlord response", value: issue.landlordResponse ?? "Pending")
                TimelineRow(title: "Follow-up", value: formatted(issue.followUpDate))
            }
            .padding(16)
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

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMProofSectionHeader(
                title: "Add follow-up",
                subtitle: "Record what the landlord said, what you sent, or how the condition changed."
            )

            VStack(alignment: .leading, spacing: 14) {
                MMTextField(
                    title: "Response or follow-up note",
                    placeholder: "What happened next?",
                    text: $followUpNote
                )

                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images,
                    preferredItemEncoding: .current
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text(isUploadingPhotos ? "Uploading…" : "Attach more photos")
                            .font(MoveMarkTheme.Typography.subheadlineMedium)
                        Spacer()
                        if !isUploadingPhotos {
                            Image(systemName: "plus")
                        }
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
                .disabled(isUploadingPhotos)

                ZStack {
                    MMButton(
                        title: "Save follow-up",
                        action: saveFollowUp,
                        kind: .primary,
                        isDisabled: isSavingFollowUp
                    )
                    .opacity(isSavingFollowUp ? 0.6 : 1)

                    if isSavingFollowUp {
                        ProgressView()
                            .tint(MoveMarkTheme.Colors.textOnPrimary)
                    }
                }
            }
            .padding(16)
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

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMSectionLabel("Status")

            Text(
                issue.status == "resolved"
                ? "Resolved. This case stays preserved in the rental record."
                : "Mark this case resolved only when the issue is actually closed. Its proof and timeline remain preserved."
            )
            .font(MoveMarkTheme.Typography.subheadline)
            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            if issue.status != "resolved" {
                ZStack {
                    MMButton(
                        title: "Mark resolved",
                        action: markResolved,
                        kind: .secondary,
                        isDisabled: isResolving
                    )
                    .opacity(isResolving ? 0.6 : 1)

                    if isResolving {
                        ProgressView()
                            .tint(MoveMarkTheme.Colors.primary)
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
                evidencePreviews = []
                return
            }
            evidencePreviews = try await fetchEvidencePreviewURLs(files: files)
        } catch {
            errorMessage = MoveMarkFlowMessage.maintenanceEvidenceLoadFailed(error)
            retryAction = { Task { await loadEvidence() } }
        }
    }

    /// Resolves both the full-size and (when present) thumbnail signed URLs for each file, so the grid can
    /// prefer the small thumbnail while still keeping the full-size path/URL around for anyone re-using it.
    private func fetchEvidencePreviewURLs(files: [EvidenceFileRow]) async throws -> [MaintenanceEvidencePreview] {
        var previews: [MaintenanceEvidencePreview] = []
        var lastError: Error?
        for file in files {
            MoveMarkStoredFileURLs.remember(rowId: file.id, filePath: file.filePath, thumbnailPath: file.thumbnailPath)
            do {
                let fullURL = try await inspectionRepo.signedURL(bucket: "maintenance-media", path: file.filePath)
                var thumbURL = fullURL
                if let thumbPath = file.thumbnailPath, thumbPath != file.filePath,
                   let resolvedThumbURL = try? await inspectionRepo.signedURL(bucket: "maintenance-media", path: thumbPath) {
                    thumbURL = resolvedThumbURL
                }
                previews.append(MaintenanceEvidencePreview(
                    id: file.id,
                    filePath: file.filePath,
                    thumbnailPath: file.thumbnailPath,
                    url: fullURL,
                    thumbURL: thumbURL
                ))
            } catch {
                lastError = error
            }
        }
        if previews.isEmpty, let lastError { throw lastError }
        return previews
    }

    /// Reload previews after upload; returns `false` if the list couldn’t be refreshed (photos may still be saved).
    private func reloadEvidencePreviewURLs() async -> Bool {
        do {
            let files = try await inspectionRepo.fetchEvidenceFilesByMaintenanceIssue(issueId: issue.id)
            evidenceFileCount = files.count
            guard !files.isEmpty else {
                evidencePreviews = []
                return true
            }
            evidencePreviews = try await fetchEvidencePreviewURLs(files: files)
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
                let upload: MoveMarkUpload
                do {
                    let source = try MMEvidenceImport.source(from: data, captureSource: .library)
                    upload = try await maintenanceRepo.uploadAttachment(source, propertyId: issue.propertyId, issueId: issue.id)
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
                        filePath: upload.path,
                        thumbnailPath: upload.thumbnailPath,
                        sourcePath: upload.sourcePath,
                        fileType: "image",
                        capturedAt: upload.capturedAt ?? Date()
                    )
                } catch {
                    await maintenanceRepo.abandonUpload(upload)
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

/// One maintenance evidence file's resolved preview URLs (full-size and thumbnail).
struct MaintenanceEvidencePreview: Identifiable {
    let id: UUID
    let filePath: String
    let thumbnailPath: String?
    /// Full-size signed URL — not displayed in the grid, kept for parity with other evidence previews.
    let url: URL
    /// Signed URL for `thumbnailPath` when present, else the same as `url`.
    let thumbURL: URL
}

// MARK: - Maintenance evidence thumbnail (path-keyed disk cache; falls back to full re-fetch on failure)

private struct MaintenanceEvidenceThumbnail: View {
    let preview: MaintenanceEvidencePreview
    let propertyId: UUID
    let onSignedURLExpired: () -> Void

    var body: some View {
        MMCachedAsyncImage(path: preview.thumbnailPath ?? preview.filePath, signedURL: preview.thumbURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                Color.clear
                    .onAppear {
                        Task {
                            await MoveMarkSignedURLCache.shared.invalidateKeys(containing: propertyId.uuidString)
                            await MainActor.run { onSignedURLExpired() }
                        }
                    }
            case .empty:
                MoveMarkTheme.Surface.raised
            }
        }
        .frame(width: 128, height: 128)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MoveMarkTheme.Stroke.normal, lineWidth: 1)
        )
    }
}
