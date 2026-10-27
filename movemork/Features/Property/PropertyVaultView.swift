//
//  PropertyVaultView.swift
//  movemork
//
//  MoveMark — The rental record: owns its state, uploads and backend calls; PropertyVaultContent draws it.
//

import SwiftUI
import PhotosUI

private struct VaultDocumentQuickLookItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    let title: String
}

struct PropertyVaultView: View {
    let property: PropertyRecord
    @Binding var path: [AppRoute]
    /// When set, show hero header with matchedGeometryEffect from vault card.
    var namespace: Namespace.ID? = nil
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var uploadSoftNotice: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showFilePicker = false
    @State private var pendingFileDocType = ""
    @State private var showEditProperty = false
    @State private var documentRows: [PropertyDocumentRow] = []
    @State private var deleteConfirmType: String? = nil
    @State private var previewErrorMessage: String? = nil
    @State private var lastFailedPhotoDocType: String? = nil
    @State private var lastFailedFileDocType: String? = nil
    @State private var contentVisible = false
    @State private var showReplacePhotoSheet = false
    @State private var pendingPhotoDocType: String? = nil

    @State private var proofToast: MMProofToastMessage? = nil
    @State private var proofToastVisible = false
    @State private var lastKnownReadinessScore: Int? = nil
    @State private var lastKnownUploadedDocumentCount: Int? = nil
    @State private var lastKnownExportReady: Bool? = nil

    @State private var highlightedDocumentType: VaultDocumentType? = nil
    @State private var pulseExportsTile = false
    @State private var pulseDisputeTile = false
    @State private var pulseQueueHeadRoomId: UUID? = nil
    @State private var showPaywall = false
    @State private var activePaywallReason: PaywallReason = .disputePacket
    @State private var showAllSupportingRecords = false
    @State private var showPropertyDetails = false
    @State private var documentQuickLook: VaultDocumentQuickLookItem?
    @State private var documentPreviewTempURL: URL?
    @State private var isPreparingDocumentPreview = false
    /// Server-computed vault dashboard; when nil, UI falls back to ``PropertyStore`` (offline / API error).
    @State private var vaultSummary: VaultSummaryResponse?
    @State private var vaultSummaryError: String? = nil

    private let documentRepo = DocumentRepository()

    private static let documentTypeOrder: [VaultDocumentType] = [.lease, .depositReceipt, .listingScreenshot, .cleaningReceipt, .utilityProof, .moveOutInvoice, .other]
    private static let priorityDocumentTypes: [VaultDocumentType] = [.lease, .depositReceipt, .listingScreenshot]

    private var completedRooms: Int {
        if let v = vaultSummary { return v.walkthrough.documentedRooms }
        return propertyStore.documentedRoomCount(for: property)
    }
    private var totalRooms: Int {
        if let v = vaultSummary { return v.walkthrough.totalRooms }
        return propertyStore.totalRoomCount(for: property)
    }
    private var totalPhotos: Int { propertyStore.totalPhotoCount(for: property) }
    private var progress: Double {
        if let v = vaultSummary, v.walkthrough.totalRooms > 0 {
            return Double(v.walkthrough.documentedRooms) / Double(v.walkthrough.totalRooms)
        }
        return propertyStore.roomsCompletionProgress(for: property)
    }
    private var nextRoom: RoomRecord? {
        if let idString = vaultSummary?.walkthrough.nextRoom?.roomId,
           let uuid = UUID(uuidString: idString),
           let match = property.rooms.first(where: { $0.id == uuid }) {
            return match
        }
        return propertyStore.nextRoomToCapture(for: property)
    }
    private var missingRecordsCount: Int {
        if let v = vaultSummary { return v.supportingRecords.missingRequired }
        return propertyStore.missingSupportingRecordCount(for: property)
    }
    private var openIssuesCount: Int {
        if let v = vaultSummary { return v.maintenance.openCount }
        return propertyStore.openIssueCount(for: property)
    }
    private var readinessScore: Int {
        if let v = vaultSummary { return v.readiness.score }
        return propertyStore.readinessScore(for: property)
    }

    private var uploadedDocumentCount: Int {
        propertyStore.uploadedSupportingRecordCount(for: property)
    }

    private var exportReady: Bool {
        propertyStore.isExportReady(for: property)
    }

    var body: some View {
        PropertyVaultContent(
            model: vaultModel,
            showAllRecords: $showAllSupportingRecords,
            showDetails: $showPropertyDetails,
            appeared: contentVisible,
            onPrimary: {
                // "Capture Kitchen" opens Kitchen; anything else continues the guided list.
                if case .captureRoom(let roomID, _) = propertyStore.primaryNextAction(for: property) {
                    path.append(.roomDetail(roomID: roomID))
                } else if let next = nextRoom, !MMRoomProofMetrics.isDocumented(next) {
                    path.append(.roomDetail(roomID: next.id))
                } else {
                    path.append(.walkthrough)
                }
            },
            onRetrySummary: { Task { await loadVaultSummary() } },
            onSeeAllRooms: { path.append(.walkthrough) },
            onOpenRoom: { roomID in path.append(.roomDetail(roomID: roomID)) },
            onRetryUpload: retryDocumentUpload,
            onViewRecord: { docType in Task { await previewDocument(type: docType) } },
            onUploadRecord: { docType in startUpload(for: docType) },
            onDeleteRecord: { docType in deleteConfirmType = docType.rawValue },
            onLink: { link in
                switch link {
                case .maintenance: path.append(.maintenance)
                case .moveOut: path.append(.moveOut)
                case .caseBuilder:
                    if subscriptionManager.canUseCaseBuilder() {
                        path.append(.exports)
                    } else {
                        activePaywallReason = .disputePacket
                        showPaywall = true
                    }
                case .exports: path.append(.exports)
                }
            },
            onEdit: { showEditProperty = true }
        )
        .id(property.id)
        .mmProofToast(message: proofToast, isVisible: proofToastVisible)
        .sheet(isPresented: $showEditProperty) {
            NavigationStack {
                EditPropertyView(property: property)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showEditProperty = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(
                reason: activePaywallReason,
                onClose: { showPaywall = false }
            )
        }
        .task(id: property.id) {
            vaultSummaryError = nil
            async let documents: Void = loadDocumentRows()
            async let vault: Void = loadVaultSummary()
            _ = await (documents, vault)
            captureBaselineIfNeeded()
        }
        .onAppear {
            contentVisible = true
            captureBaselineIfNeeded()
            consumePendingVaultFeedbackIfNeeded()
        }
        .onDisappear {
            contentVisible = false
        }
        .alert("Delete document?", isPresented: Binding(get: { deleteConfirmType != nil }, set: { if !$0 { deleteConfirmType = nil } })) {
            Button("Cancel", role: .cancel) {
                deleteConfirmType = nil
            }
            Button("Delete", role: .destructive) {
                if let type = deleteConfirmType {
                    Task { await confirmDeleteDocument(type: type) }
                }
                deleteConfirmType = nil
            }
        } message: {
            Text("This file will be removed from your vault. You can upload again later. This can't be undone.")
        }
        .onChange(of: selectedPhotoItem) { _, new in
            guard let new else { return }
            let docType = pendingPhotoDocType ?? VaultDocumentType.listingScreenshot.rawValue
            handlePhotoSelection(item: new, docType: docType)
            pendingPhotoDocType = nil
            showReplacePhotoSheet = false
        }
        .sheet(isPresented: $showReplacePhotoSheet) {
            ReplacePhotoSheet(
                onDismiss: { showReplacePhotoSheet = false },
                selection: $selectedPhotoItem,
                current: listingPreview
            )
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                handleFileSelection(url: url, docType: pendingFileDocType)
            case .failure(let error):
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                MMHaptics.error()
            }
        }
        .fullScreenCover(item: $documentQuickLook, onDismiss: {
            if let url = documentPreviewTempURL {
                try? FileManager.default.removeItem(at: url)
                documentPreviewTempURL = nil
            }
        }) { item in
            NavigationStack {
                QuickLookPreviewRepresentable(url: item.fileURL)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                documentQuickLook = nil
                            }
                        }
                    }
            }
        }
        .overlay {
            if isPreparingDocumentPreview {
                MMBusyOverlay(message: "Opening…")
            }
        }
    }

    // MARK: - Presentation model

    private var vaultModel: PropertyVaultModel {
        PropertyVaultModel(
            title: PropertyVaultModel.displayTitle(for: property),
            addressLine: PropertyVaultModel.addressLine(for: property),
            moveInLine: PropertyVaultModel.moveInLine(for: property),
            rooms: property.rooms.map { MMRentalRoom($0, isHighlighted: $0.id == pulseQueueHeadRoomId) },
            nextRoomID: nextRoom.flatMap { MMRoomProofMetrics.isDocumented($0) ? nil : $0.id }
                ?? property.rooms.first(where: { !MMRoomProofMetrics.isDocumented($0) })?.id,
            summaryError: vaultSummaryError,
            records: Self.documentTypeOrder.map { docType in
                PropertyVaultModel.Record(
                    type: docType,
                    isPresent: hasDoc(docType),
                    addedOn: recordAddedOn(for: docType),
                    file: recordFile(for: docType),
                    isHighlighted: highlightedDocumentType == docType
                )
            },
            priorityCount: Self.priorityDocumentTypes.count,
            uploadError: uploadError,
            softNotice: uploadSoftNotice,
            previewError: previewErrorMessage,
            isUploading: isUploading,
            maintenance: maintenanceSummary,
            moveOut: moveOutSummary,
            details: PropertyVaultModel.Detail.primary(for: property),
            moreDetails: PropertyVaultModel.Detail.more(for: property)
        )
    }

    /// Open and total cases: the server's summary when loaded, else this rental's hydrated log.
    private var maintenanceSummary: PropertyVaultModel.Maintenance {
        if let m = vaultSummary?.maintenance {
            return .init(open: m.openCount + m.followUpCount, total: m.openCount + m.followUpCount + m.resolvedCount)
        }
        let isActive = propertyStore.currentProperty?.id == property.id
        return .init(open: openIssuesCount, total: isActive ? propertyStore.maintenanceLog.count : nil)
    }

    /// Move-out shows once it's relevant: move-out proof exists, or the lease ends within 45 days.
    private var moveOutSummary: PropertyVaultModel.MoveOut? {
        let documentedOut = propertyStore.moveOutDocumentedRoomCount(for: property)
        let started = documentedOut > 0 || (vaultSummary?.walkthrough.hasMoveOutStarted ?? false)
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()),
                                           to: calendar.startOfDay(for: property.leaseEndDate)).day
        let leaseEnding = property.leaseEndDate.timeIntervalSince1970 > 0 && (days ?? 999) <= 45
        guard started || leaseEnding else { return nil }
        return .init(documented: documentedOut, total: totalRooms,
                     daysUntilLeaseEnd: leaseEnding && !started ? max(days ?? 0, 0) : nil)
    }

    /// When a stored record was added, if the row says.
    private func recordAddedOn(for docType: VaultDocumentType) -> String? {
        MMRecordDate.parse(docRow(for: docType.rawValue)?.uploadedAt).map(MMRecordDate.display)
    }

    /// What a stored record's file is. Photos are stored under generated names, so they read as "Image".
    private func recordFile(for docType: VaultDocumentType) -> String? {
        guard let row = docRow(for: docType.rawValue) else { return nil }
        if docType.acceptsImage { return "Image" }
        let name = row.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "PDF" : name
    }

    /// The stored listing image for the listing-proof sheet, when there is one.
    private var listingPreview: ReplacePhotoSheet.Current? {
        guard hasDoc(.listingScreenshot), let row = docRow(for: VaultDocumentType.listingScreenshot.rawValue) else { return nil }
        let bucket = DocumentRepository.storageBucket(forDocumentType: row.documentType)
        let repo = documentRepo
        return .init(path: row.thumbnailPath ?? row.filePath,
                     addedOn: MMRecordDate.parse(row.uploadedAt),
                     resolve: { path in try? await repo.signedURL(bucket: bucket, path: path) })
    }

    private func showFeedback(_ event: VaultFeedbackEvent) {
        let toast = MMProofToastMessage.fromVaultFeedback(event)
        MMProofToastPresenter.show(
            toast,
            message: $proofToast,
            isVisible: $proofToastVisible
        )
    }

    private func consumePendingVaultFeedbackIfNeeded() {
        guard let event = propertyStore.pendingVaultFeedback else { return }
        propertyStore.pendingVaultFeedback = nil
        showFeedback(event)

        let shouldPulseNextRoom: Bool = {
            switch event {
            case .roomCompleted, .moveOutRoomCompleted:
                return true
            default:
                return false
            }
        }()
        if shouldPulseNextRoom, let nextId = nextRoom?.id {
            pulseQueueHeadRoomId = nextId
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.24)) {
                    pulseQueueHeadRoomId = nil
                }
            }
        }
    }

    private func captureBaselineIfNeeded() {
        if lastKnownReadinessScore == nil {
            lastKnownReadinessScore = readinessScore
        }
        if lastKnownUploadedDocumentCount == nil {
            lastKnownUploadedDocumentCount = uploadedDocumentCount
        }
        if lastKnownExportReady == nil {
            lastKnownExportReady = exportReady
        }
    }

    /// Keeps workflow toasts / highlights accurate after deletes (upload path already updates via `evaluateWorkflowFeedback`).
    private func refreshWorkflowBaseline() {
        let prop = (propertyStore.currentProperty?.id == property.id) ? propertyStore.currentProperty! : property
        lastKnownReadinessScore = propertyStore.readinessScore(for: prop)
        lastKnownUploadedDocumentCount = propertyStore.uploadedSupportingRecordCount(for: prop)
        lastKnownExportReady = propertyStore.isExportReady(for: prop)
    }

    private func triggerDocumentHighlight(_ docType: VaultDocumentType) {
        highlightedDocumentType = docType

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            if highlightedDocumentType == docType {
                withAnimation(.easeOut(duration: 0.22)) {
                    highlightedDocumentType = nil
                }
            }
        }
    }

    private func triggerExportsPulse() {
        withAnimation(.easeInOut(duration: 0.22)) {
            pulseExportsTile = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.24)) {
                pulseExportsTile = false
            }
        }
    }

    private func triggerDisputePulse() {
        withAnimation(.easeInOut(duration: 0.22)) {
            pulseDisputeTile = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.24)) {
                pulseDisputeTile = false
            }
        }
    }

    /// Evaluate after an action (e.g. upload). Uses store's current property when matching so state is fresh. Shows one toast per run; drives row highlight and tile pulses.
    private func evaluateWorkflowFeedback(
        documentName: String? = nil,
        documentType: VaultDocumentType? = nil
    ) {
        let prop = (propertyStore.currentProperty?.id == property.id) ? propertyStore.currentProperty! : property
        let previousReadiness = lastKnownReadinessScore ?? propertyStore.readinessScore(for: prop)
        let previousDocumentCount = lastKnownUploadedDocumentCount ?? propertyStore.uploadedSupportingRecordCount(for: prop)
        let previousExportReady = lastKnownExportReady ?? propertyStore.isExportReady(for: prop)

        let newReadiness = propertyStore.readinessScore(for: prop)
        let newDocumentCount = propertyStore.uploadedSupportingRecordCount(for: prop)
        let newExportReady = propertyStore.isExportReady(for: prop)

        if let documentType, newDocumentCount > previousDocumentCount {
            triggerDocumentHighlight(documentType)
        }

        if previousExportReady == false && newExportReady == true {
            triggerExportsPulse()
        }

        let crossedIntoStrongerReadinessBand =
            (previousReadiness < 40 && newReadiness >= 40) ||
            (previousReadiness < 70 && newReadiness >= 70)

        if crossedIntoStrongerReadinessBand {
            triggerDisputePulse()
        }

        if previousExportReady == false && newExportReady == true {
            MMHaptics.success()
            showFeedback(.exportsUnlocked)
        } else if newReadiness > previousReadiness {
            MMHaptics.success()
            showFeedback(.readinessImproved(oldScore: previousReadiness, newScore: newReadiness))
        } else if let documentName, newDocumentCount > previousDocumentCount {
            MMHaptics.success()
            showFeedback(.documentUploaded(documentName: documentName))
        }

        lastKnownReadinessScore = newReadiness
        lastKnownUploadedDocumentCount = newDocumentCount
        lastKnownExportReady = newExportReady

        Task { await loadVaultSummary() }
    }

    private func docRow(for documentType: String) -> PropertyDocumentRow? {
        let keys = Set(DocumentRepository.documentTypeQueryKeys(documentType))
        return documentRows.first { keys.contains($0.documentType) }
    }

    private func hasDoc(_ type: VaultDocumentType) -> Bool {
        let keys = DocumentRepository.documentTypeQueryKeys(type.rawValue)
        return keys.contains { property.vaultDocuments.contains($0) }
    }

    private func hasVaultDocMatching(_ docType: String) -> Bool {
        let keys = DocumentRepository.documentTypeQueryKeys(docType)
        return keys.contains { property.vaultDocuments.contains($0) }
    }

    private func startUpload(for docType: VaultDocumentType) {
        if docType.acceptsImage {
            pendingPhotoDocType = docType.rawValue
            showReplacePhotoSheet = true
        } else {
            pendingFileDocType = docType.rawValue
            showFilePicker = true
        }
    }

    private func loadDocumentRows() async {
        do {
            documentRows = try await documentRepo.fetchDocuments(propertyId: property.id)
        } catch {
            documentRows = []
        }
    }

    /// Fetches server-side vault summary (rooms, docs, maintenance, readiness, exports/dispute flags). Fails silently and keeps local store UI when the API is unavailable.
    private func loadVaultSummary() async {
        guard
            let base = MoveMarkBackendConfig.apiBaseURLString
        else {
            return
        }
        do {
            let client = try ExportAPIClient(baseURLString: base)
            let summary = try await client.fetchVaultSummary(
                propertyId: property.id,
                includeExports: true,
                includeDispute: true
            )
            vaultSummary = summary
            vaultSummaryError = nil
        } catch {
            vaultSummary = nil
            vaultSummaryError = MoveMarkFlowMessage.vaultSummaryRefreshFailed
        }
    }

    /// Re-fetch rows after upload without wiping the list on failure (avoids “everything disappeared” after a successful upload).
    private func refreshDocumentRowsAfterMutation() async -> Bool {
        do {
            documentRows = try await documentRepo.fetchDocuments(propertyId: property.id)
            return true
        } catch {
            return false
        }
    }

    /// If the refetch omits a row we just inserted (read-after-write lag) or failed, merge the known-good row so preview / View work immediately.
    private func reconcileDocumentRows(anchoring expected: PropertyDocumentRow) {
        if documentRows.contains(where: { $0.id == expected.id }) { return }
        let slotKeys = Set(DocumentRepository.documentTypeQueryKeys(expected.documentType))
        let withoutSlot = documentRows.filter { !slotKeys.contains($0.documentType) }
        documentRows = [expected] + withoutSlot
    }

    private func previewDocument(type: VaultDocumentType) async {
        previewErrorMessage = nil
        uploadError = nil
        guard let row = docRow(for: type.rawValue) else {
            previewErrorMessage = MoveMarkFlowMessage.documentPreviewMissing
            return
        }
        await MainActor.run { isPreparingDocumentPreview = true }
        do {
            MoveMarkStoredFileURLs.remember(rowId: row.id, filePath: row.filePath, thumbnailPath: row.thumbnailPath)
            let remoteURL = try await documentRepo.signedURL(
                bucket: DocumentRepository.storageBucket(forDocumentType: row.documentType),
                path: row.filePath
            )
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let ext = preferredPreviewFileExtension(for: row, docType: type)
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("vault-doc-\(UUID().uuidString)", isDirectory: false)
                .appendingPathExtension(ext)
            try data.write(to: temp, options: .atomic)
            await MainActor.run {
                if let old = documentPreviewTempURL {
                    try? FileManager.default.removeItem(at: old)
                }
                documentPreviewTempURL = temp
                documentQuickLook = VaultDocumentQuickLookItem(fileURL: temp, title: type.displayTitle)
            }
        } catch {
            await MainActor.run {
                previewErrorMessage = MoveMarkFlowMessage.documentPreviewFailed(error)
            }
        }
        await MainActor.run { isPreparingDocumentPreview = false }
    }

    private func preferredPreviewFileExtension(for row: PropertyDocumentRow, docType: VaultDocumentType) -> String {
        let fromName = (row.fileName as NSString).pathExtension.lowercased()
        if !fromName.isEmpty { return fromName }
        let fromPath = (row.filePath as NSString).pathExtension.lowercased()
        if !fromPath.isEmpty { return fromPath }
        switch docType {
        case .listingScreenshot:
            return "jpg"
        default:
            return "pdf"
        }
    }

    private func confirmDeleteDocument(type: String) async {
        let slotKeys = Set(DocumentRepository.documentTypeQueryKeys(type))
        do {
            try await documentRepo.deleteDocuments(propertyId: property.id, documentType: type)
            documentRows.removeAll { slotKeys.contains($0.documentType) }
            previewErrorMessage = nil
            let metaOK = await propertyStore.refreshDocuments(propertyId: property.id)
            let rowsOK = await refreshDocumentRowsAfterMutation()
            uploadSoftNotice = nil
            uploadError = nil
            if !metaOK || !rowsOK {
                uploadSoftNotice = MoveMarkFlowMessage.documentVaultRefreshHint
            }
            refreshWorkflowBaseline()
            await loadVaultSummary()
        } catch {
            uploadError = MoveMarkFlowMessage.documentDeleteFailed(error)
        }
    }

    private func retryDocumentUpload() {
        uploadSoftNotice = nil
        if let docType = lastFailedPhotoDocType, let item = selectedPhotoItem {
            uploadError = nil
            handlePhotoSelection(item: item, docType: docType)
            return
        }
        if let docType = lastFailedFileDocType {
            uploadError = nil
            pendingFileDocType = docType
            showFilePicker = true
        }
    }

    private func handlePhotoSelection(item: PhotosPickerItem, docType: String) {
        guard let userId = sessionManager.userId else { return }
        uploadError = nil
        uploadSoftNotice = nil
        previewErrorMessage = nil
        lastFailedPhotoDocType = docType
        isUploading = true

        Task { @MainActor in
            defer { isUploading = false }
            let canonicalType = DocumentRepository.normalizedDocumentType(docType)
            // Replace never removes the current copy up front: it is retired only after the
            // new file and its row are both saved.
            var previousRows: [PropertyDocumentRow] = []
            do {
                if hasVaultDocMatching(docType) {
                    previousRows = try await documentRepo.fetchDocuments(propertyId: property.id, documentType: docType)
                }
            } catch {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                return
            }

            guard let data = try? await item.loadTransferable(type: Data.self) else {
                uploadError = MoveMarkFlowMessage.documentImageReadFailed
                return
            }
            // JPEG and PNG documents keep their bytes. HEIC/HEIF (not accepted for documents) is the one
            // conversion: a JPEG of the full image via ImageIO, never upscaled. The thumbnail is derived.
            let image: MMEvidenceSource
            do {
                image = try MMEvidenceImport.source(from: data, captureSource: .library)
            } catch {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                return
            }
            let keepsBytes = image.mimeType == "image/jpeg" || image.mimeType == "image/png"
            guard let fileBytes = keepsBytes ? image.data : MMEvidenceImport.derivative(from: image) else {
                uploadError = MoveMarkFlowMessage.documentImageReadFailed
                return
            }
            let fileName = "\(UUID()).\(keepsBytes ? image.fileExtension : "jpg")"

            // The thumbnail rides on the same upload and is best-effort: previews fall back to `filePath`.
            let upload: MoveMarkUpload
            do {
                upload = try await documentRepo.uploadDocument(
                    fileBytes,
                    fileName: fileName,
                    thumbnail: MMEvidenceImport.thumbnail(from: image),
                    propertyId: property.id,
                    documentType: canonicalType
                )
                if canonicalType == VaultDocumentType.lease.rawValue {
                    MoveMarkAnalytics.track(.leaseAdded)
                } else if canonicalType == VaultDocumentType.depositReceipt.rawValue {
                    MoveMarkAnalytics.track(.receiptAdded)
                }
            } catch {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                return
            }

            let row = PropertyDocumentRow(
                id: UUID(),
                propertyId: property.id,
                userId: userId,
                documentType: canonicalType,
                filePath: upload.path,
                thumbnailPath: upload.thumbnailPath,
                fileName: fileName,
                uploadedAt: nil,
                metadata: nil
            )
            do {
                try await documentRepo.insertDocumentRecord(row)
            } catch {
                await documentRepo.abandonUpload(upload)
                uploadError = MoveMarkFlowMessage.documentRecordCreateFailed(error)
                return
            }

            for old in previousRows where old.id != row.id {
                await documentRepo.retireDocument(old)
            }

            let metaOK = await propertyStore.refreshDocuments(propertyId: property.id)
            let rowsOK = await refreshDocumentRowsAfterMutation()
            reconcileDocumentRows(anchoring: row)
            propertyStore.ensureVaultDocumentTypePresent(propertyId: property.id, documentType: canonicalType)
            if !metaOK || !rowsOK {
                uploadSoftNotice = MoveMarkFlowMessage.documentVaultRefreshHint
            }

            if let type = VaultDocumentType(rawValue: canonicalType) {
                evaluateWorkflowFeedback(
                    documentName: type.displayTitle,
                    documentType: type
                )
            } else {
                evaluateWorkflowFeedback(documentName: "Document")
            }

            uploadError = nil
            lastFailedPhotoDocType = nil
            selectedPhotoItem = nil
        }
    }

    private func handleFileSelection(url: URL, docType: String) {
        guard let userId = sessionManager.userId else { return }
        uploadError = nil
        uploadSoftNotice = nil
        previewErrorMessage = nil
        lastFailedFileDocType = nil
        isUploading = true

        Task { @MainActor in
            defer { isUploading = false }
            let canonicalType = DocumentRepository.normalizedDocumentType(docType)
            // Replace never removes the current copy up front: it is retired only after the
            // new file and its row are both saved.
            var previousRows: [PropertyDocumentRow] = []
            do {
                if hasVaultDocMatching(docType) {
                    previousRows = try await documentRepo.fetchDocuments(propertyId: property.id, documentType: docType)
                }
            } catch {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                lastFailedFileDocType = docType
                return
            }

            guard url.startAccessingSecurityScopedResource() else {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(
                    NSError(domain: "MoveMark.Vault", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Could not access the selected file. Try again or pick a different file."
                    ])
                )
                lastFailedFileDocType = docType
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                lastFailedFileDocType = docType
                return
            }

            let fileName = url.lastPathComponent

            let upload: MoveMarkUpload
            do {
                upload = try await documentRepo.uploadDocument(
                    data,
                    fileName: fileName,
                    thumbnail: nil,
                    propertyId: property.id,
                    documentType: canonicalType
                )
                if canonicalType == VaultDocumentType.lease.rawValue {
                    MoveMarkAnalytics.track(.leaseAdded)
                } else if canonicalType == VaultDocumentType.depositReceipt.rawValue {
                    MoveMarkAnalytics.track(.receiptAdded)
                }
            } catch {
                uploadError = MoveMarkFlowMessage.documentUploadFailed(error)
                lastFailedFileDocType = docType
                return
            }

            let row = PropertyDocumentRow(
                id: UUID(),
                propertyId: property.id,
                userId: userId,
                documentType: canonicalType,
                filePath: upload.path,
                fileName: fileName,
                uploadedAt: nil,
                metadata: nil
            )
            do {
                try await documentRepo.insertDocumentRecord(row)
            } catch {
                await documentRepo.abandonUpload(upload)
                uploadError = MoveMarkFlowMessage.documentRecordCreateFailed(error)
                lastFailedFileDocType = docType
                return
            }

            for old in previousRows where old.id != row.id {
                await documentRepo.retireDocument(old)
            }

            let metaOK = await propertyStore.refreshDocuments(propertyId: property.id)
            let rowsOK = await refreshDocumentRowsAfterMutation()
            reconcileDocumentRows(anchoring: row)
            propertyStore.ensureVaultDocumentTypePresent(propertyId: property.id, documentType: canonicalType)
            if !metaOK || !rowsOK {
                uploadSoftNotice = MoveMarkFlowMessage.documentVaultRefreshHint
            }

            if let type = VaultDocumentType(rawValue: canonicalType) {
                evaluateWorkflowFeedback(
                    documentName: type.displayTitle,
                    documentType: type
                )
            } else {
                evaluateWorkflowFeedback(documentName: "Document")
            }

            uploadError = nil
            lastFailedFileDocType = nil
        }
    }
}

