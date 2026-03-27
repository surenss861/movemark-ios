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
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false

    private let checklistRepo = ChecklistRepository()
    private let exportRepo = ExportRepository()

    private var rooms: [RoomRecord] {
        propertyStore.currentProperty?.rooms ?? []
    }

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    moveOutReadinessSummary

                    checklistCard

                    roomsSection

                    exportCard

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
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet(activityItems: shareItems)
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(
                reason: activePaywallReason,
                onClose: { showPaywall = false }
            )
        }
        .task { await loadChecklist() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Move-out")
                .font(MoveMarkTheme.Typography.screenTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text("Re-capture each room at move-out. Your before-and-after record is what protects you if the landlord disputes condition or deposit.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Rectangle()
                .fill(MoveMarkTheme.Colors.accent)
                .frame(width: 38, height: 3)
                .clipShape(Capsule())
        }
    }

    private var checklistCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel(text: "Closeout proof")
                    Spacer()

                    if let checklist {
                        MMPill(
                            text: "\(checklist.completedCount) of 6 complete",
                            tone: checklist.completedCount == 6 ? .success : .warning
                        )
                    }
                }

                Text("Check off as you go. These steps strengthen your move-out record.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                checklistToggle("Cabinets cleared", keyPath: \.cabinetsClear)
                checklistToggle("Appliances cleaned", keyPath: \.appliancesClean)
                checklistToggle("Keys returned", keyPath: \.keysReturned)
                checklistToggle("Utilities cancelled", keyPath: \.utilitiesCancelled)
                checklistToggle("Cleaning receipt uploaded", keyPath: \.cleaningReceiptUploaded)
                checklistToggle("Forwarding address noted", keyPath: \.forwardingAddressNoted)
            }
        }
    }

    private var moveOutReadinessSummary: some View {
        let roomsWithMoveOut = rooms.filter { !$0.moveOutEvidence.isEmpty }.count
        let totalRooms = rooms.count
        let checklistDone = (checklist?.completedCount ?? 0)
        let checklistTotal = 6
        let allRoomsDocumented = totalRooms > 0 && roomsWithMoveOut == totalRooms

        return Group {
            if totalRooms > 0 || checklistDone > 0 {
                MMCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your move-out defense")
                                .font(MoveMarkTheme.Typography.cardTitle)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            Spacer()
                            if allRoomsDocumented && checklistDone == checklistTotal {
                                MMPill(text: "Ready to export", tone: .success)
                            }
                        }
                        Text("Document every room at move-out so you have a clear before-and-after. Export when ready.")
                            .font(MoveMarkTheme.Typography.subheadline)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rooms with move-out proof")
                                    .font(MoveMarkTheme.Typography.caption)
                                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                Text("\(roomsWithMoveOut) of \(totalRooms)")
                                    .font(MoveMarkTheme.Typography.sectionTitle)
                                    .foregroundStyle(roomsWithMoveOut == totalRooms ? MoveMarkTheme.Colors.primary : MoveMarkTheme.Colors.textPrimary)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Closeout checklist")
                                    .font(MoveMarkTheme.Typography.caption)
                                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                Text("\(checklistDone) of \(checklistTotal)")
                                    .font(MoveMarkTheme.Typography.sectionTitle)
                                    .foregroundStyle(checklistDone == checklistTotal ? MoveMarkTheme.Colors.primary : MoveMarkTheme.Colors.textPrimary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MMSectionHeader(
                title: "Before & after by room",
                subtitle: "Compare move-in baseline to move-out. Capture any room that’s missing move-out proof."
            )

            if rooms.isEmpty {
                MMCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No rooms yet")
                            .font(MoveMarkTheme.Typography.cardTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        Text("Add rooms in Walkthrough first, then return here to capture move-out proof.")
                            .font(MoveMarkTheme.Typography.subheadline)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    }
                }
            }

            ForEach(rooms) { room in
                Button {
                    path.append(.moveOutRoomDetail(roomID: room.id))
                } label: {
                    beforeAfterRoomCard(room: room)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func beforeAfterRoomCard(room: RoomRecord) -> some View {
        let latestMoveIn = room.evidence.first
        let latestMoveOut = room.moveOutEvidence.first
        let moveInEntries = room.evidence.count
        let moveInPhotos = room.evidence.reduce(0) { $0 + $1.photoCount }
        let moveOutEntries = room.moveOutEvidence.count
        let moveOutPhotos = room.moveOutEvidence.reduce(0) { $0 + $1.photoCount }
        let hasMoveIn = !room.evidence.isEmpty
        let hasMoveOut = !room.moveOutEvidence.isEmpty
        let conditionDeltaText = conditionDelta(latestMoveIn: latestMoveIn, latestMoveOut: latestMoveOut)

        return MMCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(room.name)
                        .font(MoveMarkTheme.Typography.sectionTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    Spacer()
                    if hasMoveOut {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(MoveMarkTheme.Colors.primary)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    beforeAfterBlock(
                        label: "Move-in",
                        entries: moveInEntries,
                        photos: moveInPhotos,
                        latestDate: latestMoveIn?.createdAt,
                        condition: latestMoveIn?.condition,
                        isEmpty: !hasMoveIn
                    )
                    Rectangle()
                        .fill(MoveMarkTheme.Colors.panelStroke)
                        .frame(width: 1, height: 52)
                    beforeAfterBlock(
                        label: "Move-out",
                        entries: moveOutEntries,
                        photos: moveOutPhotos,
                        latestDate: latestMoveOut?.createdAt,
                        condition: latestMoveOut?.condition,
                        isEmpty: !hasMoveOut
                    )
                }

                if !conditionDeltaText.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .medium))
                        Text(conditionDeltaText)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    }
                }

                Text(hasMoveOut ? "Tap to add more move-out proof or review." : "Tap to capture move-out proof — required for a defensible before-and-after.")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
        }
    }

    private func beforeAfterBlock(
        label: String,
        entries: Int,
        photos: Int,
        latestDate: Date?,
        condition: RoomRecord.ConditionRating?,
        isEmpty: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            if isEmpty {
                Text("No proof")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            } else {
                Text("\(entries) \(entries == 1 ? "entry" : "entries"), \(photos) photos")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                if let date = latestDate {
                    Text("Latest \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
                if let c = condition {
                    Text("Condition \(c.conditionMeterValue)/5")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var exportCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Export")

                Text("Generate a move-out report with your before-and-after room proof. Keep it, share it, or attach it to a dispute.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                ZStack {
                    MMButton(
                        title: "Export move-out report",
                        action: handleMoveOutExportTap,
                        isDisabled: isExporting || rooms.isEmpty
                    )
                    .opacity(isExporting ? 0.6 : 1.0)

                    if isExporting {
                        ProgressView().tint(MoveMarkTheme.Colors.primary)
                    }
                }

                Text(moveOutExportFootnote)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
        }
    }

    private var moveOutExportFootnote: String {
        if rooms.isEmpty {
            return "Add rooms in Walkthrough first"
        }
        let roomsWithMoveOutProof = rooms.filter { !$0.moveOutEvidence.isEmpty }.count
        if roomsWithMoveOutProof == 0 {
            return "Capture move-out proof before exporting"
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
                    var updated = checklist
                    updated[keyPath: keyPath] = newValue
                    self.checklist = updated
                    Task { await saveChecklist(updated) }
                }
            )) {
                Text(title)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            }
            .tint(MoveMarkTheme.Colors.primary)
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
            errorMessage = userFacingMoveOutError(from: error)
            lastErrorFromExport = false
        }
    }

    private func saveChecklist(_ row: MoveOutChecklistRow) async {
        do {
            try await checklistRepo.upsertChecklist(row)
        } catch {
            errorMessage = userFacingMoveOutError(from: error)
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

    private func exportMoveOutReport() {
        guard let property = propertyStore.currentProperty,
              let userId = sessionManager.userId else { return }

        isExporting = true
        errorMessage = nil

        Task { @MainActor in
            defer { isExporting = false }

            do {
                let data = PDFGenerator.generateMoveOutReport(property: property, rooms: property.rooms)
                let path = "\(userId)/\(property.id)/move_out_report/\(UUID().uuidString).pdf"
                let storedPath = try await exportRepo.uploadExport(data: data, path: path)

                try await exportRepo.insertExport(
                    ExportRow(
                        id: UUID(),
                        disputeId: nil,
                        propertyId: property.id,
                        userId: userId,
                        exportType: "move_out_report",
                        filePath: storedPath,
                        createdAt: nil
                    )
                )

                lastErrorFromExport = false
                shareItems = [data]
                showShareSheet = true
                MMHaptics.success()
            } catch {
                errorMessage = userFacingMoveOutExportError(from: error)
                lastErrorFromExport = true
            }
        }
    }

    private func userFacingMoveOutError(from error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("not authenticated") || raw.contains("jwt") || raw.contains("session") {
            return "Session expired. Please sign in again."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("internet") {
            return "No connection. Check your internet and try again."
        }
        return "Couldn’t update move-out checklist. Try again."
    }

    private func userFacingMoveOutExportError(from error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("not authenticated") || raw.contains("jwt") || raw.contains("session") {
            return "Session expired. Please sign in again."
        }
        if raw.contains("bucket") || raw.contains("storage") || raw.contains("not found") {
            return "Export storage is unavailable right now. Try again soon."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("internet") {
            return "No connection. Check your internet and try again."
        }
        return "Couldn’t export move-out report. Try again."
    }
}
