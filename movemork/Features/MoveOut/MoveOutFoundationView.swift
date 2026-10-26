//
//  MoveOutFoundationView.swift
//  movemork
//
//  MoveMark — Move-out checklist, room list, export.
//

import SwiftUI
import PhotosUI

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

    private let checklistRepo = ChecklistRepository()

    private var rooms: [RoomRecord] {
        propertyStore.currentProperty?.rooms ?? []
    }

    /// Mirrors the server's `not_enough_move_out_proof` guard: a room counts only once a move-out
    /// entry carries at least one photo. An entry without photos does not make a report possible.
    private var roomsWithMoveOutPhotos: Int {
        rooms.filter { $0.moveOutPhotoTotal > 0 }.count
    }

    private var apiBaseURL: String? { MoveMarkBackendConfig.apiBaseURLString }

    init(
        path: Binding<[AppRoute]>,
        initialChecklist: MoveOutChecklistRow? = nil,
        initiallyExporting: Bool = false,
        initialError: String? = nil,
        initialQueuedNotice: String? = nil
    ) {
        _path = path
        _checklist = State(initialValue: initialChecklist)
        _isExporting = State(initialValue: initiallyExporting)
        _errorMessage = State(initialValue: initialError)
        _queuedNotice = State(initialValue: initialQueuedNotice)
    }

    var body: some View {
        MMScreen(
            eyebrow: propertyStore.currentProperty.map { $0.title.isEmpty ? $0.addressLine1 : $0.title },
            title: "Move-out",
            subtitle: "Re-capture each room before you return the keys. Your before-and-after is what protects your deposit.",
            isPushed: true
        ) {
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

            moveOutReadinessSummary

            roomsSection

            checklistSection
                .padding(.top, 26)

            exportSection
                .padding(.top, 30)
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(
                reason: activePaywallReason,
                onClose: { showPaywall = false }
            )
        }
        .task { await loadChecklist() }
    }

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

    @ViewBuilder
    private var moveOutReadinessSummary: some View {
        let roomsWithMoveOut = rooms.filter { !$0.moveOutEvidence.isEmpty }.count
        let totalRooms = rooms.count
        let checklistDone = (checklist?.completedCount ?? 0)
        let checklistTotal = 6
        let allRoomsDocumented = totalRooms > 0 && roomsWithMoveOut == totalRooms

        if totalRooms > 0 || checklistDone > 0 {
            MMPanel {
                HStack(alignment: .top, spacing: 16) {
                    summaryStat("Rooms with move-out proof", "\(roomsWithMoveOut) of \(totalRooms)")
                    Rectangle().fill(MMInk.separator).frame(width: 0.75)
                    summaryStat("Closeout checklist", "\(checklistDone) of \(checklistTotal)")
                }
                .fixedSize(horizontal: false, vertical: true)
                if allRoomsDocumented && checklistDone == checklistTotal {
                    MMStatusLabel(text: "Ready to export", tone: .done).padding(.top, 14)
                }
            }
            .padding(.bottom, 26)
        }
    }

    private func summaryStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).mmFont(22, .semibold).foregroundStyle(MMInk.text).monospacedDigit()
            Text(label).mmFont(13).foregroundStyle(MMInk.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var roomsSection: some View {
        if rooms.isEmpty {
            MMEmptyBlock(
                icon: "arrow.left.arrow.right",
                title: "Add rooms in Room proof first",
                message: "Move-out compares each room to your move-in baseline. Create rooms and capture move-in proof, then come back for move-out photos and notes."
            )
        } else {
            MMGroup(title: "Before & after by room", footer: "Compare each room's move-in baseline to its move-out proof.") {
                ForEach(Array(rooms.enumerated()), id: \.element.id) { index, room in
                    if index > 0 { MMRowDivider() }
                    Button {
                        path.append(.moveOutRoomDetail(roomID: room.id))
                    } label: {
                        beforeAfterRoomRow(room: room)
                    }
                    .buttonStyle(MMLightPressStyle())
                }
            }
        }
    }

    private func beforeAfterRoomRow(room: RoomRecord) -> some View {
        let latestMoveIn = room.evidence.first
        let latestMoveOut = room.moveOutEvidence.first
        let hasMoveIn = !room.evidence.isEmpty
        let hasMoveOut = !room.moveOutEvidence.isEmpty
        let conditionDeltaText = conditionDelta(latestMoveIn: latestMoveIn, latestMoveOut: latestMoveOut)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(room.name).mmFont(16, .medium).foregroundStyle(MMInk.text)
                Text("Move-in · \(stageSummary(entries: room.moveInEntryTotal, photos: room.moveInPhotoTotal, hasProof: hasMoveIn, condition: latestMoveIn?.condition))")
                    .mmFont(13).foregroundStyle(MMInk.secondary)
                Text("Move-out · \(stageSummary(entries: room.moveOutEntryTotal, photos: room.moveOutPhotoTotal, hasProof: hasMoveOut, condition: latestMoveOut?.condition))")
                    .mmFont(13).foregroundStyle(MMInk.secondary)
                if !conditionDeltaText.isEmpty {
                    Text(conditionDeltaText).mmFont(13).foregroundStyle(MMInk.text.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                MMStatusLabel(text: hasMoveOut ? "Move-out captured" : "Needs move-out proof", tone: hasMoveOut ? .done : .open)
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
        .accessibilityHint(hasMoveOut ? "Add more move-out proof or review." : "Capture move-out proof.")
        .accessibilityAddTraits(.isButton)
    }

    private func stageSummary(entries: Int, photos: Int, hasProof: Bool, condition: RoomRecord.ConditionRating?) -> String {
        guard hasProof else { return "No proof" }
        var line = "\(entries) \(entries == 1 ? "entry" : "entries"), \(photos) \(photos == 1 ? "photo" : "photos")"
        if let condition { line += " · \(condition.conditionMeterValue)/5" }
        return line
    }

    private func conditionDelta(latestMoveIn: EvidenceRecord?, latestMoveOut: EvidenceRecord?) -> String {
        guard let moveIn = latestMoveIn, let moveOut = latestMoveOut else {
            if latestMoveOut == nil, latestMoveIn != nil {
                return "No move-out yet — capture to compare condition."
            }
            return ""
        }
        let inVal = moveIn.condition.conditionMeterValue
        let outVal = moveOut.condition.conditionMeterValue
        if inVal == outVal {
            return "Condition unchanged (\(inVal)/5)."
        }
        return "Condition \(inVal)/5 → \(outVal)/5."
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MMSectionTitle(title: "Move-out report")
            Text("Your before-and-after room proof in one dated PDF. Keep it, share it, or attach it to a dispute.")
                .mmFont(14)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            if let queuedNotice {
                MMNotice(message: queuedNotice, tone: .success).padding(.top, 16)
            }

            MMPrimaryButton(
                title: isExporting ? "Queuing report…" : "Export move-out report",
                isLoading: isExporting,
                isDisabled: isExporting || roomsWithMoveOutPhotos == 0,
                action: handleMoveOutExportTap
            )
            .padding(.top, 18)

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

    private var moveOutExportFootnote: String {
        if let queuedNotice {
            return queuedNotice
        }
        if rooms.isEmpty {
            return "Add rooms in Room proof first"
        }
        if roomsWithMoveOutPhotos == 0 {
            return "Capture move-out photos before exporting"
        }
        if subscriptionManager.hasPro {
            return "Included with Pro"
        }
        return "Pro required for move-out exports"
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
