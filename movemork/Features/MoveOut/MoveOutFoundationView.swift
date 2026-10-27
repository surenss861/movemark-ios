//
//  MoveOutFoundationView.swift
//  movemork
//
//  MoveMark — Move-out: every room's move-in record (the baseline) beside its move-out record, the change
//  stated first (state rule in MMSystem+MoveOut.swift), the closeout checklist, and the move-out report.
//

import SwiftUI

struct MoveOutFoundationView: View {
    @Binding var path: [AppRoute]
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var showPaywall = false
    @State private var activePaywallReason: PaywallReason = .moveOutExport
    @State private var checklist: MoveOutChecklistRow? = nil
    @State private var isLoadingChecklist = false
    @State private var isExporting = false
    @State private var errorMessage: String? = nil
    @State private var lastErrorFromExport = false
    @State private var queuedNotice: String? = nil
    @State private var viewer: ViewerTarget? = nil
    /// Rooms that gained move-out photos while this screen was open: what the renter just added.
    @State private var justCompared: Set<UUID> = []

    private struct ViewerTarget: Identifiable {
        var id: UUID { startID }
        let photos: [EvidencePhoto]
        let startID: UUID
    }

    private let checklistRepo = ChecklistRepository()
    private let inspectionRepo = InspectionRepository()

    private var rooms: [RoomRecord] {
        propertyStore.currentProperty?.rooms ?? []
    }

    /// Mirrors the server's `not_enough_move_out_proof` guard: a room counts only once a move-out
    /// entry carries at least one photo. An entry without photos does not make a report possible.
    private var roomsWithMoveOutPhotos: Int {
        rooms.filter { $0.moveOutPhotoTotal > 0 }.count
    }

    private var apiBaseURL: String? { MoveMarkBackendConfig.apiBaseURLString }

    private var rentalName: String {
        guard let property = propertyStore.currentProperty else { return "Move-out" }
        let title = property.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = title.isEmpty ? property.addressLine1 : title
        let unit = property.addressLine2.trimmingCharacters(in: .whitespacesAndNewlines)
        return unit.isEmpty || name.localizedCaseInsensitiveContains(unit) ? name : "\(name), \(unit)"
    }

    private var comparisons: [MoveOutComparison] { rooms.map(MoveOutComparison.make(room:)) }

    /// All rooms compared, or nearly all (at least 90% and at most one room left).
    private var isSubstantiallyCompared: Bool {
        guard !rooms.isEmpty else { return false }
        let missing = rooms.count - roomsWithMoveOutPhotos
        return missing == 0 || (missing == 1 && Double(roomsWithMoveOutPhotos) / Double(rooms.count) >= 0.9)
    }

    /// Move-in photos exist somewhere: without them there is no baseline to compare against.
    private var hasBaseline: Bool { rooms.contains { $0.moveInPhotoTotal > 0 } }

    /// Every room has move-out photos, so the report is the next step.
    private var isComplete: Bool { !rooms.isEmpty && roomsWithMoveOutPhotos == rooms.count }

    init(
        path: Binding<[AppRoute]>,
        initialChecklist: MoveOutChecklistRow? = nil,
        initiallyExporting: Bool = false,
        initialError: String? = nil,
        initialQueuedNotice: String? = nil,
        initialJustCompared: Set<UUID> = []
    ) {
        _justCompared = State(initialValue: initialJustCompared)
        _path = path
        _checklist = State(initialValue: initialChecklist)
        _isExporting = State(initialValue: initiallyExporting)
        _errorMessage = State(initialValue: initialError)
        _queuedNotice = State(initialValue: initialQueuedNotice)
    }

    var body: some View {
        MMScreen(
            eyebrow: "Move-out",
            title: rentalName,
            subtitle: "Compare what changed since move-in.",
            isPushed: true,
            showsWordmark: true,
            headerAccessory: rooms.isEmpty || !hasBaseline ? nil : AnyView(
                MoveOutHeaderProgress(done: roomsWithMoveOutPhotos, total: rooms.count)
            )
        ) {
            if let gained = justComparedLine {
                MMNotice(message: gained, tone: .success).padding(.bottom, 18)
            }

            if let errorMessage {
                MMNotice(
                    message: errorMessage,
                    actionTitle: MMCopy.tryAgain,
                    action: {
                        if lastErrorFromExport {
                            exportMoveOutReport()
                        } else {
                            Task { await loadChecklist() }
                        }
                    }
                )
                .padding(.bottom, 18)
            }

            if hasBaseline {
                comparisonSections
            } else {
                MMEmptyBlock(
                    icon: "square.split.2x1",
                    title: "No move-in proof to compare yet",
                    message: rooms.isEmpty
                        ? "Add your rooms and photograph each one as it is now. Before you leave, you’ll capture them again here and see what changed — and what didn’t."
                        : "Photograph each room as it is now. Before you leave, you’ll capture them again here and see what changed — and what didn’t.",
                    actionTitle: "Capture move-in proof",
                    action: { path.append(.walkthrough) }
                )
            }

            checklistSection
                .padding(.top, 30)

            // Without a baseline there is nothing to report on yet; the empty block says what to do.
            if hasBaseline {
                exportSection
                    .padding(.top, 30)
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(
                reason: activePaywallReason,
                onClose: { showPaywall = false }
            )
        }
        .fullScreenCover(item: $viewer) { target in
            RoomPhotoViewer(photos: target.photos, startID: target.startID, resolvePhotoURL: resolvePhotoURL,
                            onClose: { viewer = nil })
        }
        .task { await loadChecklist() }
        // A room that gains its move-out side while this screen is open (back from capture) reads as compared.
        .onChange(of: missingRoomIDs) { old, new in
            justCompared.formUnion(old.subtracting(new))
        }
    }

    private var missingRoomIDs: Set<UUID> { Set(rooms.filter { $0.moveOutPhotoTotal == 0 }.map(\.id)) }

    private var justComparedLine: String? {
        let names = rooms.filter { justCompared.contains($0.id) && $0.moveOutPhotoTotal > 0 }.map(\.name)
        guard let first = names.first else { return nil }
        switch names.count {
        case 1: return "\(first) now has proof at both ends, compared with your move-in record."
        case 2: return "\(first) and \(names[1]) now have proof at both ends, compared with your move-in record."
        default: return "\(names.count) more rooms now have proof at both ends, compared with your move-in record."
        }
    }

    // MARK: - Comparisons

    @ViewBuilder
    private var comparisonSections: some View {
        let all = comparisons
        // New issues first, then lower condition; each keeps the rooms' own order.
        let changed = all.filter { $0.state == .newIssue } + all.filter { $0.state == .changed }
        let missing = all.filter { $0.state == .missing }
        let unchanged = all.filter { $0.state == .unchanged }
        let notCompared = all.filter { $0.state == .noBaseline }

        ScrollViewReader { proxy in
        VStack(alignment: .leading, spacing: 30) {
            // The page's index: tap a count to jump to those rooms.
            MMPanel {
                MoveOutTally(changed: changed.count, missing: missing.count, unchanged: unchanged.count) { index in
                    withAnimation { proxy.scrollTo(["changed", "missing", "unchanged"][index], anchor: .top) }
                }
                if isSubstantiallyCompared {
                    // The quiet payoff: reassurance that the record is now whole, not a celebration.
                    Rectangle().fill(MMInk.separator).frame(height: 0.75).padding(.vertical, 14)
                    Text(missing.isEmpty
                         ? "Your move-out record now shows how the rental changed since move-in."
                         : "Your move-out record now shows how most of the rental changed since move-in.")
                        .mmFont(14)
                        .foregroundStyle(MMInk.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !changed.isEmpty {
                section(title: "What changed", count: changed.count,
                        caption: "Compare move-in and move-out proof room by room.") {
                    ForEach(changed) { spread($0) }
                }
                .id("changed")
            }

            if !missing.isEmpty {
                section(title: "Move-out proof needed", count: missing.count,
                        caption: "Capture from the same angles as move-in.") {
                    ForEach(missing) { item in
                        // Lime on the first missing room only: while rooms are missing, capture is the one action.
                        missingCard(item, isPrimary: item.id == missing.first?.id)
                    }
                }
                .id("missing")
            }

            if !unchanged.isEmpty {
                MMGroup(title: "Unchanged · \(unchanged.count)",
                        footer: "Photographed at both ends with no new issue and no lower condition. Tap a room to compare its photos.") {
                    ForEach(Array(unchanged.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { MMRowDivider() }
                        compactRow(item)
                    }
                }
                .id("unchanged")
            }

            if !notCompared.isEmpty {
                MMGroup(title: "Not compared · \(notCompared.count)",
                        footer: "These rooms have move-out photos but no move-in photos, so there is nothing to compare them with.") {
                    ForEach(Array(notCompared.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { MMRowDivider() }
                        compactRow(item)
                    }
                }
            }
        }
        }
    }

    private func section<Content: View>(title: String, count: Int, caption: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).mmFont(17, .semibold).foregroundStyle(MMInk.text).accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(count) \(count == 1 ? "room" : "rooms")").mmFont(13).monospacedDigit().foregroundStyle(MMInk.secondary)
            }
            Text(caption).mmFont(13).foregroundStyle(MMInk.secondary).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
            VStack(spacing: 12) { content() }.padding(.top, 12)
        }
    }

    private func spread(_ item: MoveOutComparison) -> some View {
        MoveOutSpreadCard(comparison: item, resolve: resolvePhotoURL, justCompared: justCompared.contains(item.id),
                          onOpenPhoto: { openViewer(item, $0) })
    }

    private func missingCard(_ item: MoveOutComparison, isPrimary: Bool) -> some View {
        MoveOutMissingCard(comparison: item, resolve: resolvePhotoURL, isPrimary: isPrimary,
                           onOpenPhoto: { openViewer(item, $0) },
                           onCapture: { path.append(.moveOutRoomDetail(roomID: item.id)) })
    }

    private func compactRow(_ item: MoveOutComparison) -> some View {
        MoveOutCompactRow(
            comparison: item, resolve: resolvePhotoURL, justCompared: justCompared.contains(item.id),
            onOpenPhoto: { openViewer(item, $0) }
        )
    }

    private func openViewer(_ item: MoveOutComparison, _ side: MoveOutSide) {
        let photos = side == .moveIn ? item.moveInPhotos : item.moveOutPhotos
        guard let first = photos.first else { return }
        viewer = ViewerTarget(photos: photos, startID: first.id)
    }

    private func resolvePhotoURL(_ path: String) async -> URL? {
        try? await inspectionRepo.signedURL(bucket: "inspection-media", path: path)
    }

    // MARK: - Checklist

    @ViewBuilder
    private var checklistSection: some View {
        if let checklist {
            MMGroup(title: "Closeout checklist · \(checklist.completedCount) of 6", footer: "Check off as you go. Each step adds to your move-out record.") {
                checklistToggle("Cabinets cleared", keyPath: \.cabinetsClear)
                MMRowDivider()
                checklistToggle("Appliances cleaned", keyPath: \.appliancesClean)
                MMRowDivider()
                checklistToggle("Keys returned", keyPath: \.keysReturned)
                MMRowDivider()
                checklistToggle("Utilities cancelled", keyPath: \.utilitiesCancelled)
                MMRowDivider()
                checklistToggle("Cleaning receipt uploaded", keyPath: \.cleaningReceiptUploaded)
                MMRowDivider()
                checklistToggle("Forwarding address noted", keyPath: \.forwardingAddressNoted)
            }
        } else if isLoadingChecklist {
            MMGroup(title: "Closeout checklist") {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small).tint(MMInk.secondary)
                    Text("Loading checklist…").mmFont(15).foregroundStyle(MMInk.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(minHeight: MMMetrics.rowHeight)
            }
        }
    }

    // MARK: - Report

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MMSectionTitle(title: "Move-out report")
            Text("Turn your comparison into one organized PDF: each room’s move-in and move-out proof side by side, dated.")
                .mmFont(14)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            if let queuedNotice {
                // What the renter gained: the report is on its way; Reports is where it lands (and can be redone).
                MMNotice(message: queuedNotice, tone: .success).padding(.top, 16)
                if isComplete {
                    MMPrimaryButton(title: "Open Reports", icon: "doc.text") { path.append(.exports) }
                        .padding(.top, 14)
                } else {
                    // Rooms still missing keep capture as the one lime action.
                    MMSecondaryButton(title: "Open Reports", icon: "doc.text") { path.append(.exports) }
                        .padding(.top, 6)
                }
            } else if isComplete {
                // Lime only once every room is captured; until then capturing the next room is the primary action.
                MMPrimaryButton(
                    title: isExporting ? "Queuing report…" : "Generate move-out report",
                    isLoading: isExporting,
                    isDisabled: isExporting,
                    action: handleMoveOutExportTap
                )
                .padding(.top, 18)
            } else {
                MMSecondaryButton(
                    title: isExporting ? "Queuing report…" : partialExportTitle,
                    icon: "doc.text",
                    isDisabled: isExporting || roomsWithMoveOutPhotos == 0,
                    action: handleMoveOutExportTap
                )
                .padding(.top, 12)
            }

            if queuedNotice == nil {
                Text(moveOutExportFootnote)
                    .mmFont(12.5)
                    .foregroundStyle(MMInk.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
        }
    }

    private var partialExportTitle: String {
        roomsWithMoveOutPhotos > 0 ? "Generate report with \(roomsWithMoveOutPhotos) of \(rooms.count) rooms" : "Generate move-out report"
    }

    private var moveOutExportFootnote: String {
        if rooms.isEmpty {
            return "Add rooms in Room proof first"
        }
        if roomsWithMoveOutPhotos == 0 {
            return "Capture move-out proof before generating the report"
        }
        if subscriptionManager.hasPro {
            return "Included with Pro"
        }
        return "Pro required for move-out reports"
    }

    @ViewBuilder
    private func checklistToggle(_ title: String, keyPath: WritableKeyPath<MoveOutChecklistRow, Bool>) -> some View {
        if let checklist {
            Toggle(isOn: Binding(
                get: { checklist[keyPath: keyPath] },
                set: { newValue in
                    guard let before = self.checklist else { return }
                    var updated = before
                    updated[keyPath: keyPath] = newValue
                    self.checklist = updated
                    Task { @MainActor in
                        do {
                            try await checklistRepo.upsertChecklist(updated)
                        } catch {
                            self.checklist = before
                            errorMessage = MoveMarkFlowMessage.moveOutChecklistSaveFailed(error)
                            lastErrorFromExport = false
                        }
                    }
                }
            )) {
                Text(title)
                    .mmFont(16)
                    .foregroundStyle(MMInk.text)
            }
            .tint(MMInk.text)
            .padding(.horizontal, 16)
            .frame(minHeight: MMMetrics.rowHeight)
        }
    }

    private func loadChecklist() async {
        guard let property = propertyStore.currentProperty,
              let userId = sessionManager.userId else { return }

        isLoadingChecklist = true
        defer { isLoadingChecklist = false }

        do {
            if let row = try await checklistRepo.fetchChecklist(propertyId: property.id, userId: userId) {
                checklist = row
            } else {
                let created = MoveOutChecklistRow(
                    id: UUID(),
                    propertyId: property.id,
                    userId: userId,
                    cabinetsClear: false,
                    appliancesClean: false,
                    keysReturned: false,
                    utilitiesCancelled: false,
                    cleaningReceiptUploaded: false,
                    forwardingAddressNoted: false
                )
                try await checklistRepo.upsertChecklist(created)
                checklist = created
            }
        } catch {
            errorMessage = MoveMarkFlowMessage.moveOutChecklistSaveFailed(error)
            lastErrorFromExport = false
        }
    }

    private func handleMoveOutExportTap() {
        guard subscriptionManager.canExportMoveOut() else {
            activePaywallReason = .moveOutExport
            showPaywall = true
            return
        }
        exportMoveOutReport()
    }

    /// Queues the report on the API, which owns the proof and Pro checks, the export row, and the
    /// PDF (rendered by the worker). The finished report appears in Reports, which downloads and
    /// shares it through the authenticated API.
    private func exportMoveOutReport() {
        guard let property = propertyStore.currentProperty else { return }
        guard roomsWithMoveOutPhotos > 0 else { return }
        guard let baseURL = apiBaseURL else {
            errorMessage = "API base URL is missing. Set MoveMarkAPIBaseURL in build settings."
            lastErrorFromExport = false
            return
        }

        isExporting = true
        errorMessage = nil
        queuedNotice = nil

        Task { @MainActor in
            defer { isExporting = false }

            do {
                let apiClient = try ExportAPIClient(baseURLString: baseURL)
                _ = try await apiClient.requestMoveOutExport(propertyId: property.id)
                lastErrorFromExport = false
                queuedNotice = "Report queued — it will appear in Reports when ready"
                NotificationCenter.default.post(name: .moveMarkExportsShouldRefresh, object: nil)
                MMHaptics.success()
            } catch {
                errorMessage = MoveMarkFlowMessage.exportOrAPIFailed(
                    error,
                    fallback: "Couldn't queue move-out report. Try again.",
                    intent: .mutate
                )
                lastErrorFromExport = true
                MMHaptics.error()
            }
        }
    }
}
