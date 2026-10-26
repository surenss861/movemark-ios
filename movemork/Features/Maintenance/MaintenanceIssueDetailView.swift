//
//  MaintenanceIssueDetailView.swift
//  movemork
//
//  MoveMark — Issue detail with timeline, evidence, follow-up, resolve.
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

    init(issue: MaintenanceIssueRow, initialError: String? = nil) {
        _issue = State(initialValue: issue)
        _errorMessage = State(initialValue: initialError)
    }

    var body: some View {
        MMScreen(
            eyebrow: issue.category ?? "General",
            title: issue.title,
            subtitle: (issue.description?.isEmpty == false) ? issue.description : nil,
            isPushed: true
        ) {
            if let errorMessage {
                MMNotice(
                    message: errorMessage,
                    actionTitle: retryAction != nil ? MMCopy.tryAgain : nil,
                    action: retryAction
                )
                .padding(.bottom, 18)
            } else if let softNotice {
                MMNotice(message: softNotice, tone: .info).padding(.bottom, 18)
            }

            statusLine

            recordSection.padding(.top, 18)

            if evidenceFileCount > 0 {
                evidenceSection.padding(.top, 28)
            }

            followUpSection.padding(.top, 28)

            resolveSection.padding(.top, 22)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEvidence() }
        .onChange(of: selectedPhotos) { _, newItems in
            uploadPhotos(newItems)
        }
    }

    private var isResolved: Bool { issue.status == "resolved" }

    private var statusLine: some View {
        HStack(spacing: 10) {
            MMStatusLabel(text: issue.status.capitalized, tone: isResolved ? .done : .open)
            Spacer(minLength: 8)
        }
    }

    private var recordSection: some View {
        MMGroup(title: "Record") {
            VStack(alignment: .leading, spacing: 0) {
                MMRecordStepRow(title: "Discovered", value: formatted(issue.dateDiscovered), isRecorded: issue.dateDiscovered?.isEmpty == false)
                MMRecordStepRow(title: "Reported", value: formatted(issue.dateReported), isRecorded: issue.dateReported?.isEmpty == false)
                MMRecordStepRow(title: "Landlord response", value: responseText, isRecorded: issue.landlordResponse?.isEmpty == false)
                MMRecordStepRow(title: "Follow-up", value: formatted(issue.followUpDate), isRecorded: issue.followUpDate?.isEmpty == false, isLast: true)
            }
            .padding(16)
        }
    }

    private var responseText: String {
        guard let response = issue.landlordResponse, !response.isEmpty else { return "No response recorded" }
        return response
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMSectionTitle(title: evidenceFileCount == 1 ? "1 photo" : "\(evidenceFileCount) photos")
            if isLoadingEvidence && evidencePreviews.isEmpty {
                ProgressView().tint(MMInk.secondary).frame(maxWidth: .infinity, minHeight: 96)
            } else if evidencePreviews.isEmpty {
                MMNotice(
                    message: "Couldn’t load photo previews. Your files may still be saved.",
                    tone: .warning,
                    actionTitle: "Retry",
                    action: { Task { await loadEvidence() } }
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(evidencePreviews) { preview in
                            MaintenanceEvidenceThumbnail(preview: preview, propertyId: issue.propertyId) {
                                Task { await loadEvidence() }
                            }
                        }
                    }
                }
            }
        }
    }

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MMSectionTitle(title: "Follow-up")
            Text("Record what your landlord said, what you sent, or what happened next.")
                .mmFont(14)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            MMField(
                title: "Landlord response / follow-up note",
                placeholder: "What happened next",
                text: $followUpNote,
                axis: .vertical
            )
            .padding(.top, 16)

            MMGroup {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images,
                    preferredItemEncoding: .current
                ) {
                    MMPhotoPickerLabel(
                        title: isUploadingPhotos ? "Uploading…" : "Attach more photos",
                        icon: "paperclip",
                        isBusy: isUploadingPhotos
                    )
                }
                .buttonStyle(MMLightPressStyle())
                .disabled(isUploadingPhotos)
            }
            .padding(.top, 14)

            MMPrimaryButton(title: "Save follow-up", isLoading: isSavingFollowUp, isDisabled: isSavingFollowUp, action: saveFollowUp)
                .padding(.top, 22)
        }
    }

    @ViewBuilder
    private var resolveSection: some View {
        if isResolved {
            Text("This issue is marked resolved and stays in your record.")
                .mmFont(13.5)
                .foregroundStyle(MMInk.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 2) {
                MMSecondaryButton(title: isResolving ? "Marking resolved…" : "Mark resolved", icon: "checkmark",
                                  isDisabled: isResolving, action: markResolved)
                Text("Once it's fixed. The proof stays preserved.")
                    .mmFont(12.5)
                    .foregroundStyle(MMInk.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
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
                // The picked file is the source evidence (its real type, never relabelled); the derivative
                // and thumbnail are made from it and the whole set is verified before the row is written.
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
                MMInk.field
            }
        }
        .frame(width: 112, height: 112)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(MMInk.cardStroke, lineWidth: 0.75))
    }
}
