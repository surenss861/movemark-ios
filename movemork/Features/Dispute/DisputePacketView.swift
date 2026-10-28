//
//  DisputePacketView.swift
//  movemork
//
//  @file The evidence packet builder, live: reads the rental, its maintenance log and its exports, keeps the
//        renter's note on what is being questioned on this iPhone (the disputes table is read-only to clients),
//        and generates / views / shares the dispute packet through the same export API as Reports.
//

import SwiftUI

struct DisputePacketView: View {
    @Binding var path: [AppRoute]
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SubscriptionManager.self) private var subscriptionManager

    private struct PreviewItem: Identifiable {
        let id = UUID()
        let fileURL: URL
    }

    private struct ViewerTarget: Identifiable {
        var id: UUID { startID }
        let photos: [EvidencePhoto]
        let startID: UUID
        let subject: String
        let captions: [UUID: RoomPhotoViewer.Caption]
    }

    @State private var question = ""
    @State private var amount = ""
    @State private var selectedRoomIDs: Set<UUID> = []
    @State private var exports: [ExportRow] = []
    @State private var statuses: [UUID: ExportStatus] = [:]
    @State private var errorMessage: String?
    @State private var isRequesting = false
    @State private var isDownloading = false
    @State private var preview: PreviewItem?
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var showPaywall = false
    @State private var viewer: ViewerTarget?
    @State private var restored = false

    private let inspectionRepo = InspectionRepository()

    var body: some View {
        Group {
            if let property = propertyStore.currentProperty {
                DisputePacketContent(
                    model: model(for: property),
                    question: $question,
                    amount: $amount,
                    resolve: resolvePhotoURL,
                    errorMessage: errorMessage,
                    isDownloading: isDownloading,
                    onToggleRoom: { id in
                        if selectedRoomIDs.contains(id) { selectedRoomIDs.remove(id) } else { selectedRoomIDs.insert(id) }
                    },
                    onOpenPhoto: { item, side in openViewer(item, side, rooms: property.rooms) },
                    onCaptureMoveOut: { path.append(.moveOutRoomDetail(roomID: $0)) },
                    onMissing: { target in
                        switch target {
                        case .rentalRecord: path.append(.vaultDetail(propertyId: property.id))
                        case .moveOut: path.append(.moveOut)
                        case .rooms: path.append(.walkthrough)
                        case .reports: path.append(.exports)
                        }
                    },
                    onGenerate: generate,
                    onView: { open(share: false) },
                    onShare: { open(share: true) },
                    onRetry: { Task { await loadExports() } }
                )
                .task(id: property.id) {
                    restoreDraft(propertyID: property.id)
                    await loadExports()
                    await pollWhileGenerating()
                }
                .onChange(of: question) { saveDraft(propertyID: property.id) }
                .onChange(of: amount) { saveDraft(propertyID: property.id) }
                .onChange(of: selectedRoomIDs) { saveDraft(propertyID: property.id) }
            } else {
                MMRecordScreen(eyebrow: "Dispute packet", title: "No rental yet") {
                    MMEmptyBlock(icon: "doc.richtext", title: "No rental yet",
                                 message: "A packet is assembled from a rental's recorded evidence.")
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(reason: .disputePacket, onClose: { showPaywall = false })
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty { ReportPDFShareSheet(activityItems: shareItems) }
        }
        .fullScreenCover(item: $preview) { item in
            NavigationStack {
                QuickLookPreviewRepresentable(url: item.fileURL)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle("Evidence packet")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Done") { preview = nil } }
                    }
            }
        }
        .fullScreenCover(item: $viewer) { target in
            RoomPhotoViewer(photos: target.photos, startID: target.startID, subject: target.subject,
                            captions: target.captions, resolvePhotoURL: resolvePhotoURL, onClose: { viewer = nil })
        }
    }

    // MARK: Model

    private enum ExportStatus { case active, ready, failed }

    private func model(for property: PropertyRecord) -> DisputePacketModel {
        var model = DisputePacketModel.make(
            property: property, maintenance: propertyStore.maintenanceLog, exports: exports,
            readyIDs: ids(.ready), activeIDs: ids(.active), failedIDs: ids(.failed),
            selectedRoomIDs: selectedRoomIDs, hasPro: subscriptionManager.canUseCaseBuilder()
        )
        if isRequesting, model.packet != .needsMoveInProof { model = model.with(packet: .generating) }
        return model
    }

    private func ids(_ status: ExportStatus) -> Set<UUID> {
        Set(statuses.filter { $0.value == status }.map(\.key))
    }

    // MARK: Draft (on this iPhone)

    private func draftKey(_ propertyID: UUID) -> String { "mm.disputeDraft.\(propertyID.uuidString)" }

    private func restoreDraft(propertyID: UUID) {
        guard !restored else { return }
        restored = true
        guard let data = UserDefaults.standard.data(forKey: draftKey(propertyID)),
              let draft = try? JSONDecoder().decode(Draft.self, from: data) else {
            // First open: start from what MoveMark already found — the rooms that differ at move-out.
            let rooms = propertyStore.currentProperty?.rooms ?? []
            selectedRoomIDs = Set(rooms.filter {
                let state = MoveOutComparison.make(room: $0).state
                return state == .changed || state == .newIssue
            }.map(\.id))
            return
        }
        question = draft.question
        amount = draft.amount
        selectedRoomIDs = Set(draft.rooms)
    }

    private func saveDraft(propertyID: UUID) {
        guard restored else { return }
        let draft = Draft(question: question, amount: amount, rooms: Array(selectedRoomIDs))
        if let data = try? JSONEncoder().encode(draft) { UserDefaults.standard.set(data, forKey: draftKey(propertyID)) }
    }

    private struct Draft: Codable {
        let question: String
        let amount: String
        let rooms: [UUID]
    }

    // MARK: Exports

    private func client() throws -> ExportAPIClient {
        guard let base = MoveMarkBackendConfig.apiBaseURLString else { throw APIClientError.invalidBaseURL }
        return try ExportAPIClient(baseURLString: base)
    }

    private func loadExports() async {
        guard let propertyID = propertyStore.currentProperty?.id else { return }
        do {
            let items = try await client().fetchExports(propertyId: propertyID)
            var next: [UUID: ExportStatus] = [:]
            for item in items {
                switch item.status {
                case .queued, .processing: next[item.id] = .active
                case .failed: next[item.id] = .failed
                case .completed:
                    let path = (item.filePath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !path.isEmpty { next[item.id] = .ready }
                }
            }
            exports = items.map {
                ExportRow(id: $0.id, disputeId: nil, propertyId: $0.propertyId, userId: $0.userId,
                          exportType: $0.type, filePath: $0.filePath, createdAt: $0.requestedAt ?? $0.createdAt)
            }
            statuses = next
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load this rental's packets just now. Your evidence is unchanged."
        }
    }

    private func pollWhileGenerating() async {
        for _ in 0..<48 {
            let generating = exports.contains {
                ($0.exportType == "dispute_packet" || $0.exportType == "dispute_summary") && statuses[$0.id] == .active
            }
            guard generating else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await loadExports()
        }
    }

    private func generate() {
        guard let property = propertyStore.currentProperty, !isRequesting else { return }
        guard subscriptionManager.canUseCaseBuilder() else {
            showPaywall = true
            return
        }
        isRequesting = true
        errorMessage = nil
        Task { @MainActor in
            defer { isRequesting = false }
            do {
                _ = try await client().requestDisputePacketExport(propertyId: property.id)
                NotificationCenter.default.post(name: .moveMarkExportsShouldRefresh, object: nil)
                await loadExports()
                MMHaptics.success()
            } catch {
                errorMessage = MoveMarkFlowMessage.exportOrAPIFailed(
                    error, fallback: "Couldn't start the evidence packet. Try again.", intent: .mutate)
                MMHaptics.error()
                return
            }
            await pollWhileGenerating()
        }
    }

    private func latestPacket() -> ExportRow? {
        exports
            .filter { ($0.exportType == "dispute_packet" || $0.exportType == "dispute_summary") && statuses[$0.id] == .ready }
            .max { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
    }

    private func open(share: Bool) {
        guard let row = latestPacket() else { return }
        isDownloading = true
        errorMessage = nil
        Task { @MainActor in
            defer { isDownloading = false }
            do {
                let response = try await client().fetchDownloadURL(exportId: row.id.uuidString)
                guard let signed = URL(string: response.downloadUrl) else { throw APIClientError.invalidResponse }
                let local = try await ReportFileDownloader.downloadPDF(from: signed, exportType: row.exportType)
                try ReportFileDownloader.validateReportFile(at: local)
                if share {
                    shareItems = [try ReportFileDownloader.makeShareItem(for: local, exportType: row.exportType)]
                    showShareSheet = true
                    MoveMarkAnalytics.track(.reportShared, properties: ["type": row.exportType])
                } else {
                    preview = PreviewItem(fileURL: local)
                }
            } catch {
                errorMessage = (error as? ReportFileError)?.localizedDescription
                    ?? MoveMarkFlowMessage.documentPreviewFailed(error)
                MMHaptics.error()
            }
        }
    }

    // MARK: Photos

    private func openViewer(_ item: MoveOutComparison, _ side: MoveOutSide, rooms: [RoomRecord]) {
        let photos = side == .moveIn ? item.moveInPhotos : item.moveOutPhotos
        guard let first = photos.first else { return }
        let room = rooms.first { $0.id == item.id }
        let entries = side == .moveIn ? room?.evidence : room?.moveOutEvidence
        viewer = ViewerTarget(photos: photos, startID: first.id, subject: room?.name ?? "",
                              captions: RoomPhotoViewer.captions(for: entries ?? []))
    }

    private func resolvePhotoURL(_ path: String) async -> URL? {
        try? await inspectionRepo.signedURL(bucket: "inspection-media", path: path)
    }
}

extension DisputePacketModel {
    /// The same model with the packet state replaced (a request in flight reads as generating).
    func with(packet: Packet) -> DisputePacketModel {
        DisputePacketModel(title: title, rooms: rooms, selectedRoomIDs: selectedRoomIDs, records: records,
                           missing: missing, moveInPhotos: moveInPhotos, moveOutPhotos: moveOutPhotos,
                           documents: documents, issues: issues, moveInReportIncluded: moveInReportIncluded,
                           packet: packet, hasPro: hasPro)
    }
}
