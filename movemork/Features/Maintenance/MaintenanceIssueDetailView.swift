//
//  MaintenanceIssueDetailView.swift
//  movemork
//
//  MoveMark — Maintenance case file: the case header, lead evidence photo + strip (tap → viewer), the case
//  timeline from the record, details, the follow-up composer and Mark resolved.
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
    /// The case's evidence rows (capture metadata + paths); images resolve through the evidence pipeline.
    @State private var evidenceFiles: [EvidenceFileRow] = []
    @State private var hasLoadedEvidence = false
    @State private var isLoadingEvidence = false
    @State private var evidenceLoadFailed = false
    @State private var errorMessage: String? = nil
    @State private var softNotice: String? = nil
    @State private var retryAction: (() -> Void)? = nil
    @State private var isResolving = false
    @State private var isConfirmingResolve = false
    @State private var viewerTarget: ViewerTarget? = nil

    private let inspectionRepo = InspectionRepository()
    private let maintenanceRepo = MaintenanceRepository()

    private struct ViewerTarget: Identifiable { let id: UUID }

    /// `initialEvidence` pre-fills the case's photos (previews / snapshots) and skips the first fetch.
    init(issue: MaintenanceIssueRow, initialError: String? = nil, initialEvidence: [EvidenceFileRow]? = nil) {
        _issue = State(initialValue: issue)
        _errorMessage = State(initialValue: initialError)
        if let initialEvidence {
            _evidenceFiles = State(initialValue: initialEvidence)
            _hasLoadedEvidence = State(initialValue: true)
        }
    }

    var body: some View {
        MMCaseScreen(
            title: issue.title,
            line: issue.category,
            reported: MMCaseDate.text(issue.dateReported ?? issue.dateDiscovered),
            status: caseStatus
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

            evidenceSection

            timelineSection.padding(.top, 30)

            if let details = issue.description?.trimmingCharacters(in: .whitespacesAndNewlines), !details.isEmpty {
                detailsSection(details).padding(.top, 30)
            }

            // A resolved case is closed: no further entries, so its resolution date holds.
            if !isResolved {
                followUpSection.padding(.top, 32)
            }

            resolveSection.padding(.top, 22)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasLoadedEvidence else { return }
            await loadEvidence()
        }
        .onChange(of: selectedPhotos) { _, newItems in
            uploadPhotos(newItems)
        }
        .fullScreenCover(item: $viewerTarget) { target in
            RoomPhotoViewer(
                photos: orderedPhotos.map { EvidencePhoto(id: $0.id, filePath: $0.filePath, thumbnailPath: $0.thumbnailPath) },
                startID: target.id,
                subject: issue.title,
                captions: viewerCaptions,
                resolvePhotoURL: resolvePhotoURL,
                onClose: { viewerTarget = nil }
            )
        }
    }

    private var isResolved: Bool { issue.status == "resolved" }

    private var caseStatus: MMCaseStatusMark.State {
        switch issue.status {
        case "resolved": .resolved
        case "follow_up": .followUp
        default: .open
        }
    }

    private func resolvePhotoURL(_ path: String) async -> URL? {
        try? await inspectionRepo.signedURL(bucket: "maintenance-media", path: path)
    }

    // MARK: Evidence

    /// Newest first: the lead photo is the latest thing recorded.
    private var orderedPhotos: [EvidenceFileRow] {
        evidenceFiles.enumerated().sorted { a, b in
            let da = Self.photoDate(a.element), db = Self.photoDate(b.element)
            if let da, let db, da != db { return da > db }
            return a.offset > b.offset
        }.map(\.element)
    }

    private static func photoDate(_ file: EvidenceFileRow) -> Date? {
        MMCaseDate.parse(file.capturedAt)?.date ?? MMCaseDate.parse(file.createdAt)?.date
    }

    private var viewerCaptions: [UUID: RoomPhotoViewer.Caption] {
        Dictionary(evidenceFiles.map { file in
            let declared = MMCaseDate.parse(file.capturedAt)?.date
            return (file.id, RoomPhotoViewer.Caption(
                phase: "Maintenance",
                date: declared ?? MMCaseDate.parse(file.createdAt)?.date,
                dateVerb: declared != nil ? "Captured" : "Recorded"
            ))
        }, uniquingKeysWith: { first, _ in first })
    }

    private func evidenceImage(_ file: EvidenceFileRow, thumb: Bool, size: CGSize?) -> some View {
        MMEvidenceImage(path: thumb ? (file.thumbnailPath ?? file.filePath) : file.filePath,
                        resolve: resolvePhotoURL, size: size, placeholder: MMInk.field)
    }

    private var photoCountText: String {
        evidenceFiles.count == 1 ? "1 photo recorded" : "\(evidenceFiles.count) photos recorded"
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            let photos = orderedPhotos
            if let lead = photos.first {
                MMCaseLeadPhoto(accessibilityLabel: "Lead evidence photo, \(photoCountText)",
                                action: { viewerTarget = ViewerTarget(id: lead.id) }) {
                    evidenceImage(lead, thumb: false, size: CGSize(width: 362, height: 272))
                }
                Text(photoCountText)
                    .mmFont(13.5, .medium)
                    .monospacedDigit()
                    .foregroundStyle(MMInk.text)
                    .padding(.top, 10)
                if photos.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(photos.dropFirst().enumerated()), id: \.element.id) { offset, file in
                                Button { viewerTarget = ViewerTarget(id: file.id) } label: {
                                    MMCaseThumb(side: 64) { evidenceImage(file, thumb: true, size: CGSize(width: 64, height: 64)) }
                                }
                                .buttonStyle(MMLightPressStyle())
                                .accessibilityLabel("Evidence photo \(offset + 2) of \(photos.count)")
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            } else if isLoadingEvidence || !hasLoadedEvidence {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MMInk.field)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .overlay { ProgressView().tint(MMInk.secondary) }
                    .accessibilityElement()
                    .accessibilityLabel("Loading evidence")
            } else {
                MMMissingPhotoFrame(label: evidenceLoadFailed ? "Photos couldn't load" : "No photos recorded for this case")
                    .frame(height: 120)
            }

            MMGroup {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images,
                    preferredItemEncoding: .current
                ) {
                    MMPhotoPickerLabel(
                        title: isUploadingPhotos ? "Uploading…" : (evidenceFiles.isEmpty ? "Add photos" : "Add more photos"),
                        icon: "camera",
                        isBusy: isUploadingPhotos
                    )
                }
                .buttonStyle(MMLightPressStyle())
                .disabled(isUploadingPhotos)
            }
            .padding(.top, 14)
        }
    }

    // MARK: Timeline

    private struct CaseEvent: Identifiable {
        let id: String
        let title: String
        let date: Date?
        let dateText: String?
        var detail: String? = nil
        var isPending = false
    }

    /// The chronology from what the record holds: discovered (when earlier than the report), recorded,
    /// the landlord follow-up, and resolution — or a quiet pending step while the case is open. Nothing else.
    private var events: [CaseEvent] {
        var dated: [CaseEvent] = []
        let reported = MMCaseDate.parse(issue.dateReported)
        let discovered = MMCaseDate.parse(issue.dateDiscovered)
        if let discovered, let reported, discovered.date < reported.date {
            dated.append(CaseEvent(id: "discovered", title: "Issue discovered", date: discovered.date,
                                   dateText: MMCaseDate.text(discovered.date, time: discovered.hasTime)))
        }
        if let recorded = reported ?? discovered {
            let method = issue.reportMethod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            dated.append(CaseEvent(id: "recorded", title: "Case recorded", date: recorded.date,
                                   dateText: MMCaseDate.text(recorded.date, time: recorded.hasTime),
                                   detail: method.isEmpty ? nil : "Reported to landlord by \(method.lowercased())"))
        }
        dated.sort { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        // Each dated follow-up entry is its own step, in the order written; the latest carries the stored follow-up time.
        let entries = MaintenanceFollowUpLog.entries(issue.landlordResponse)
        let followUp = MMCaseDate.parse(issue.followUpDate)
        if entries.isEmpty, let followUp {
            dated.append(CaseEvent(id: "followup", title: "Landlord follow-up", date: followUp.date,
                                   dateText: MMCaseDate.text(followUp.date, time: followUp.hasTime)))
        }
        for (index, entry) in entries.enumerated() {
            let isLatest = index == entries.count - 1
            let dateText = isLatest ? (followUp.map { MMCaseDate.text($0.date, time: $0.hasTime) } ?? entry.day) : entry.day
            dated.append(CaseEvent(id: "followup-\(index)", title: dateText == nil ? "Landlord response" : "Landlord follow-up",
                                   date: nil, dateText: dateText, detail: entry.text))
        }
        if isResolved {
            let resolved = MMCaseDate.parse(issue.updatedAt)
            dated.append(CaseEvent(id: "resolved", title: "Repair completed", date: resolved?.date,
                                   dateText: resolved.map { MMCaseDate.text($0.date, time: $0.hasTime) }))
        } else {
            dated.append(CaseEvent(id: "pending", title: "Repair pending", date: nil, dateText: nil, isPending: true))
        }
        return dated
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            caption("Case timeline")
            MMPanel(padding: 18) {
                let items = events
                ForEach(Array(items.enumerated()), id: \.element.id) { index, event in
                    MMCaseTimelineRow(title: event.title, date: event.dateText, detail: event.detail,
                                      isFirst: index == 0, isLast: index == items.count - 1, isPending: event.isPending)
                }
            }
        }
    }

    private func detailsSection(_ details: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            caption("Details")
            Text(details)
                .mmFont(15.5)
                .foregroundStyle(MMInk.text)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text.uppercased())
            .mmFont(12, .semibold)
            .tracking(0.6)
            .foregroundStyle(MMInk.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Follow-up / resolve

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MMSectionTitle(title: "Add to the record")
            Text("What your landlord said, what you sent, or what happened next. It joins the timeline, dated.")
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

            MMPrimaryButton(title: "Save follow-up", isLoading: isSavingFollowUp,
                            isDisabled: isSavingFollowUp || trimmedFollowUp.isEmpty, action: saveFollowUp)
                .padding(.top, 18)
        }
    }

    @ViewBuilder
    private var resolveSection: some View {
        if isResolved {
            Text("This case is resolved and stays in your record.")
                .mmFont(13.5)
                .foregroundStyle(MMInk.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 2) {
                MMSecondaryButton(title: isResolving ? "Marking resolved…" : "Mark resolved", icon: "checkmark",
                                  isDisabled: isResolving, action: { isConfirmingResolve = true })
                Text("Once it's fixed. The case and its photos stay preserved.")
                    .mmFont(12.5)
                    .foregroundStyle(MMInk.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .confirmationDialog("Mark this case resolved?", isPresented: $isConfirmingResolve, titleVisibility: .visible) {
                Button("Mark resolved", action: markResolved)
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: Data

    private func loadEvidence() async {
        softNotice = nil
        errorMessage = nil
        retryAction = nil
        isLoadingEvidence = true
        defer { isLoadingEvidence = false }
        do {
            let files = try await inspectionRepo.fetchEvidenceFilesByMaintenanceIssue(issueId: issue.id)
            remember(files)
            evidenceFiles = files
            evidenceLoadFailed = false
            hasLoadedEvidence = true
        } catch {
            evidenceLoadFailed = true
            hasLoadedEvidence = true
            errorMessage = MoveMarkFlowMessage.maintenanceEvidenceLoadFailed(error)
            retryAction = { Task { await loadEvidence() } }
        }
    }

    private func remember(_ files: [EvidenceFileRow]) {
        for file in files {
            MoveMarkStoredFileURLs.remember(rowId: file.id, filePath: file.filePath, thumbnailPath: file.thumbnailPath)
        }
    }

    /// Reload the evidence rows after upload; returns `false` if the list couldn’t be refreshed (photos may still be saved).
    private func reloadEvidence() async -> Bool {
        do {
            let files = try await inspectionRepo.fetchEvidenceFilesByMaintenanceIssue(issueId: issue.id)
            remember(files)
            evidenceFiles = files
            evidenceLoadFailed = false
            return true
        } catch {
            return false
        }
    }

    /// Uploads in order and stops at the first failure; Try again picks up from the photo that failed, so saved
    /// photos aren't uploaded twice. `skipped` carries photos that couldn't be read across retries.
    private func uploadPhotos(_ items: [PhotosPickerItem], skipped previouslySkipped: Int = 0) {
        guard !items.isEmpty else { return }

        isUploadingPhotos = true
        errorMessage = nil
        softNotice = nil
        retryAction = nil

        Task { @MainActor in
            defer { isUploadingPhotos = false }

            var skipped = previouslySkipped
            for (index, item) in items.enumerated() {
                // The picked file is the source evidence (its real type, never relabelled); the derivative
                // and thumbnail are made from it and the whole set is verified before the row is written.
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let source = try? await MMEvidenceImport.sourceOffMain(from: data, captureSource: .library) else {
                    skipped += 1
                    continue
                }
                let remaining = Array(items[index...])
                let upload: MoveMarkUpload
                do {
                    upload = try await maintenanceRepo.uploadAttachment(source, propertyId: issue.propertyId, issueId: issue.id)
                } catch {
                    errorMessage = MoveMarkFlowMessage.maintenancePhotoUploadFailed(error)
                    retryAction = { [skipped] in uploadPhotos(remaining, skipped: skipped) }
                    _ = await reloadEvidence()
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
                    retryAction = { [skipped] in uploadPhotos(remaining, skipped: skipped) }
                    _ = await reloadEvidence()
                    return
                }
            }
            selectedPhotos = []
            let reloaded = await reloadEvidence()
            var notices: [String] = []
            if skipped > 0 {
                notices.append(skipped == 1 ? "1 photo couldn't be read." : "\(skipped) photos couldn't be read.")
            }
            if !reloaded {
                notices.append(MoveMarkFlowMessage.maintenanceEvidencePreviewHint.trimmingCharacters(in: .whitespaces))
            }
            softNotice = notices.isEmpty ? nil : notices.joined(separator: " ")
        }
    }

    private var trimmedFollowUp: String {
        followUpNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveFollowUp() {
        let note = trimmedFollowUp
        guard !isSavingFollowUp, !note.isEmpty else { return }

        isSavingFollowUp = true
        errorMessage = nil
        retryAction = nil

        Task { @MainActor in
            defer { isSavingFollowUp = false }

            do {
                let response = try await maintenanceRepo.updateFollowUp(id: issue.id, note: note,
                                                                        fallbackExisting: issue.landlordResponse)
                var updated = issue
                let now = ISO8601DateFormatter().string(from: Date())
                updated.landlordResponse = response
                updated.followUpDate = now
                updated.updatedAt = now
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
                updated.updatedAt = ISO8601DateFormatter().string(from: Date())
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
