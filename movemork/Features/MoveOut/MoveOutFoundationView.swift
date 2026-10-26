//
//  MoveOutFoundationView.swift
//  movemork
//
//  MoveMark — move-out comparison and closeout proof.
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

    private var orderedRooms: [RoomRecord] {
        rooms.sorted { lhs, rhs in
            let lhsMissing = lhs.moveOutPhotoTotal == 0
            let rhsMissing = rhs.moveOutPhotoTotal == 0
            if lhsMissing != rhsMissing { return lhsMissing && !rhsMissing }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var checklistDone: Int {
        checklist?.completedCount ?? 0
    }

    private var roomCompletion: Double {
        guard !rooms.isEmpty else { return 0 }
        return Double(roomsWithMoveOutPhotos) / Double(rooms.count)
    }

    private var apiBaseURL: String? { MoveMarkBackendConfig.apiBaseURLString }

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.sectionGap) {
                    header

                    readinessStrip

                    roomsSection

                    closeoutSection

                    exportSection

                    if let errorMessage {
                        MMErrorBanner(
                            message: errorMessage,
                            retryTitle: MMCopy.tryAgain,
                            onRetry: {
                                if lastErrorFromExport {
                                    exportMoveOutReport()
                                } else {
                                    Task { await loadChecklist() }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 22)
                .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(
                reason: activePaywallReason,
                onClose: { showPaywall = false }
            )
        }
        .task { await loadChecklist() }
        .navigationTitle("Move-out")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MOVE-OUT RECORD")
                .font(MoveMarkTheme.Typography.sectionLabel)
                .tracking(0.9)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

            Text("Compare what changed.")
                .font(MoveMarkTheme.Typography.pageTitle)
                .tracking(-0.8)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Re-capture each room before you leave. MoveMark keeps the move-in baseline beside the move-out record so condition changes are easy to explain later.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var readinessStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Move-out proof")
                    .font(MoveMarkTheme.Typography.rowTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Spacer()

                Text("\(roomsWithMoveOutPhotos) of \(rooms.count) rooms")
                    .font(MoveMarkTheme.Typography.metadata)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }

            ProgressView(value: roomCompletion)
                .tint(MoveMarkTheme.Colors.primary)

            HStack(spacing: 18) {
                readinessMetric(value: "\(roomsWithMoveOutPhotos)/\(rooms.count)", label: "Rooms compared")
                readinessMetric(value: "\(checklistDone)/6", label: "Closeout steps")

                Spacer(minLength: 0)

                if !rooms.isEmpty,
                   roomsWithMoveOutPhotos == rooms.count,
                   checklistDone == 6 {
                    Text("READY")
                        .font(MoveMarkTheme.Typography.sectionLabel)
                        .tracking(0.8)
                        .foregroundStyle(MoveMarkTheme.Colors.semanticSuccess)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func readinessMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(MoveMarkTheme.Typography.cardTitleCompact)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(label)
                .font(MoveMarkTheme.Typography.metadata)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
    }

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMProofSectionHeader(
                title: "Before & after",
                subtitle: "Rooms missing move-out photos come first. Open one to capture or review its comparison."
            )

            if rooms.isEmpty {
                MMEmptyState(
                    systemImage: "arrow.left.arrow.right.circle",
                    title: "Add rooms and move-in proof first",
                    message: "Move-out compares each room to its move-in baseline. Add rooms and capture move-in proof, then return here."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(orderedRooms.enumerated()), id: \.element.id) { index, room in
                        Button {
                            path.append(.moveOutRoomDetail(roomID: room.id))
                        } label: {
                            roomComparisonRow(room)
                        }
                        .buttonStyle(.plain)

                        if index < orderedRooms.count - 1 {
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
    }

    private func roomComparisonRow(_ room: RoomRecord) -> some View {
        let latestMoveIn = room.evidence.first
        let latestMoveOut = room.moveOutEvidence.first
        let hasMoveOut = room.moveOutPhotoTotal > 0
        let delta = conditionDelta(latestMoveIn: latestMoveIn, latestMoveOut: latestMoveOut)

        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(room.name)
                    .font(MoveMarkTheme.Typography.rowTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(hasMoveOut ? MoveMarkTheme.Colors.semanticSuccess : MoveMarkTheme.Colors.semanticWarning)
                        .frame(width: 7, height: 7)

                    Text(hasMoveOut ? "Compared" : "Needs move-out proof")
                        .font(MoveMarkTheme.Typography.metadata)
                        .foregroundStyle(hasMoveOut ? MoveMarkTheme.Colors.textSecondary : MoveMarkTheme.Colors.semanticWarning)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                comparisonBlock(
                    label: "Move-in",
                    entries: room.moveInEntryTotal,
                    photos: room.moveInPhotoTotal,
                    latestDate: latestMoveIn?.createdAt,
                    condition: latestMoveIn?.condition,
                    isEmpty: room.evidence.isEmpty
                )

                Rectangle()
                    .fill(MoveMarkTheme.Stroke.normal)
                    .frame(width: 1, height: 64)

                comparisonBlock(
                    label: "Move-out",
                    entries: room.moveOutEntryTotal,
                    photos: room.moveOutPhotoTotal,
                    latestDate: latestMoveOut?.createdAt,
                    condition: latestMoveOut?.condition,
                    isEmpty: room.moveOutEvidence.isEmpty
                )
            }

            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(MoveMarkTheme.Typography.metadata)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)

                Text(delta.isEmpty ? "Capture move-out proof to create a comparison." : delta)
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(MoveMarkTheme.Typography.metadata)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
        }
        .padding(.vertical, MoveMarkTheme.Spacing.rowVertical)
        .contentShape(Rectangle())
    }

    private func comparisonBlock(
        label: String,
        entries: Int,
        photos: Int,
        latestDate: Date?,
        condition: RoomRecord.ConditionRating?,
        isEmpty: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(MoveMarkTheme.Typography.sectionLabel)
                .tracking(0.7)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

            if isEmpty {
                Text("No proof")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            } else {
                Text("\(photos) photo\(photos == 1 ? "" : "s")")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text("\(entries) entr\(entries == 1 ? "y" : "ies")")
                    .font(MoveMarkTheme.Typography.metadata)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                if let date = latestDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(MoveMarkTheme.Typography.metadata)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }

                if let condition {
                    Text("Condition \(condition.conditionMeterValue)/5")
                        .font(MoveMarkTheme.Typography.metadata)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func conditionDelta(latestMoveIn: EvidenceRecord?, latestMoveOut: EvidenceRecord?) -> String {
        guard let moveIn = latestMoveIn, let moveOut = latestMoveOut else {
            if latestMoveOut == nil, latestMoveIn != nil {
                return "Move-out proof is still missing."
            }
            return ""
        }

        let inVal = moveIn.condition.conditionMeterValue
        let outVal = moveOut.condition.conditionMeterValue
        if inVal == outVal {
            return "Condition unchanged at \(inVal)/5."
        }
        return "Condition \(inVal)/5 → \(outVal)/5."
    }

    private var closeoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMProofSectionHeader(
                title: "Closeout",
                subtitle: "Finish the practical handoff steps that support the room evidence."
            )

            if isLoadingChecklist && checklist == nil {
                ProgressView()
                    .tint(MoveMarkTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    checklistToggle("Cabinets cleared", keyPath: \.cabinetsClear)
                    divider
                    checklistToggle("Appliances cleaned", keyPath: \.appliancesClean)
                    divider
                    checklistToggle("Keys returned", keyPath: \.keysReturned)
                    divider
                    checklistToggle("Utilities cancelled", keyPath: \.utilitiesCancelled)
                    divider
                    checklistToggle("Cleaning receipt uploaded", keyPath: \.cleaningReceiptUploaded)
                    divider
                    checklistToggle("Forwarding address noted", keyPath: \.forwardingAddressNoted)
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
    }

    private var divider: some View {
        Divider()
            .overlay(MoveMarkTheme.Stroke.normal)
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMProofSectionHeader(
                title: "Move-out report",
                subtitle: "Package the before-and-after room record into a report you can preview and share."
            )

            ZStack {
                MMButton(
                    title: "Generate move-out report",
                    action: handleMoveOutExportTap,
                    kind: .primary,
                    isDisabled: isExporting || roomsWithMoveOutPhotos == 0
                )
                .opacity(isExporting ? 0.6 : 1)

                if isExporting {
                    ProgressView()
                        .tint(MoveMarkTheme.Colors.textOnPrimary)
                }
            }

            Text(moveOutExportFootnote)
                .font(MoveMarkTheme.Typography.metadata)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var moveOutExportFootnote: String {
        if let queuedNotice {
            return queuedNotice
        }
        if rooms.isEmpty {
            return "Add rooms and move-in proof first."
        }
        if roomsWithMoveOutPhotos == 0 {
            return "Capture move-out photos before generating the report."
        }
        if subscriptionManager.hasPro {
            return "Included with MoveMark Pro."
        }
        return "MoveMark Pro is required for move-out reports."
    }

    @ViewBuilder
    private func checklistToggle(
        _ title: String,
        keyPath: WritableKeyPath<MoveOutChecklistRow, Bool>
    ) -> some View {
        if let checklist {
            Toggle(
                isOn: Binding(
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
                )
            ) {
                Text(title)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            }
            .tint(MoveMarkTheme.Colors.primary)
            .padding(.vertical, 13)
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
                queuedNotice = "Report queued — it will appear in Reports when ready."
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
