//
//  RoomListView.swift
//  movemork
//
//  MoveMark — Walkthrough: elevated progress, quiet room rows, report card.
//

import SwiftUI
import Supabase

struct RoomListView: View {
    @Binding var path: [AppRoute]
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var showAddRoom = false
    @State private var showPaywall = false
    @State private var activePaywallReason: PaywallReason = .unlimitedExports
    @State private var isExporting = false
    @State private var errorMessage: String? = nil
    @State private var lastErrorFromExport = false
    @State private var exportSuccessBanner: String? = nil

    private var rooms: [RoomRecord] {
        propertyStore.currentProperty?.rooms ?? []
    }

    private var completedCount: Int {
        rooms.filter { !$0.evidence.isEmpty }.count
    }

    private var progress: Double {
        guard !rooms.isEmpty else { return 0 }
        return Double(completedCount) / Double(rooms.count)
    }

    private var nextRoom: RoomRecord? {
        rooms.first(where: { $0.evidence.isEmpty }) ?? rooms.first
    }

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    walkthroughHeader

                    progressCard

                    if let exportSuccessBanner {
                        MMCard(tone: .quiet, padding: 14, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(MoveMarkTheme.Colors.primary)
                                Text(exportSuccessBanner)
                                    .font(MoveMarkTheme.Typography.subheadline)
                                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            }
                        }
                    }

                    if let errorMessage {
                        MMErrorBanner(
                            message: errorMessage,
                            retryTitle: MMCopy.tryAgain,
                            onRetry: {
                                if lastErrorFromExport {
                                    exportMoveInReport()
                                }
                            }
                        )
                    }

                    roomsSection

                    moveInReportCard

                    moveOutCard
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
        .navigationTitle("Walkthrough")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MMButton(
                    title: "Add room",
                    action: { showAddRoom = true },
                    kind: .quiet,
                    size: .compact,
                    expandsToFillWidth: false
                )
            }
        }
        .sheet(isPresented: $showAddRoom) {
            NavigationStack {
                AddRoomSheetView(onDismiss: { showAddRoom = false })
                    .navigationTitle("Add room")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") {
                                showAddRoom = false
                            }
                            .foregroundStyle(MoveMarkTheme.Colors.primary)
                        }
                    }
            }
        }
    }

    private var walkthroughHeader: some View {
        MMEditorialHeader(
            eyebrow: "MoveMark",
            title: "Walkthrough",
            subtitle: "Build your move-in record one room at a time."
        )
    }

    private var progressCard: some View {
        MMCard(tone: .elevated, padding: 18, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    ProgressRingView(
                        progress: progress,
                        size: 64,
                        lineWidth: 4,
                        label: rooms.isEmpty ? "0" : "\(completedCount)"
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Proof progress")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(MoveMarkTheme.Colors.accent)
                            .textCase(.uppercase)

                        if rooms.isEmpty {
                            Text("No rooms yet")
                                .font(MoveMarkTheme.Typography.cardTitle)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                            Text("Add your first room below.")
                                .font(MoveMarkTheme.Typography.subheadline)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        } else if completedCount >= rooms.count {
                            Text("\(completedCount) of \(rooms.count) rooms documented")
                                .font(MoveMarkTheme.Typography.cardTitle)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                            Text("Move-in record complete. Export a report or review your rooms.")
                                .font(MoveMarkTheme.Typography.subheadline)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        } else {
                            Text("\(completedCount) of \(rooms.count) rooms documented")
                                .font(MoveMarkTheme.Typography.cardTitle)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                            if let nextRoom {
                                Text("Next room to capture: \(nextRoom.name)")
                                    .font(MoveMarkTheme.Typography.subheadline)
                                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            }
                        }
                    }

                    Spacer()
                }

                if let nextRoom, !rooms.isEmpty {
                    if completedCount >= rooms.count {
                        MMButton(
                            title: "Review rooms",
                            action: { path.append(.roomDetail(roomID: rooms[0].id)) },
                            kind: .secondary,
                            size: .standard
                        )
                    } else {
                        MMButton(
                            title: "Open next room — \(nextRoom.name)",
                            action: { path.append(.roomDetail(roomID: nextRoom.id)) },
                            kind: .primary,
                            size: .hero
                        )
                    }
                }
            }
        }
    }

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rooms")
                    .font(MoveMarkTheme.Typography.caption)
                    .tracking(1.0)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                Spacer()

                if !rooms.isEmpty {
                    Text("\(completedCount) of \(rooms.count) documented")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }

            if rooms.isEmpty {
                MMCard(tone: .quiet, padding: 18, spacing: 8) {
                    Text("No rooms yet")
                        .font(MoveMarkTheme.Typography.sectionTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("Tap Add room above to add your first room, then tap it to capture proof.")
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(rooms.enumerated()), id: \.element.id) { idx, room in
                    roomRow(index: idx + 1, room: room)
                }
            }
        }
    }

    private var moveInReportCard: some View {
        MMCard(tone: .quiet, padding: 18, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Move-in report")
                    .font(MoveMarkTheme.Typography.sectionTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text("Export a PDF of your move-in evidence by room. Use it as your baseline record.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                MMButton(
                    title: isExporting ? "Exporting…" : "Export move-in report",
                    action: handleMoveInExportTap,
                    kind: .secondary,
                    size: .standard,
                    isDisabled: isExporting || rooms.isEmpty || completedCount == 0
                )

                Text(moveInExportFootnote)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
        }
    }

    private var moveOutCard: some View {
        Button {
            path.append(.moveOut)
        } label: {
            MMCard(tone: .quiet, padding: 18, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open move-out")
                            .font(MoveMarkTheme.Typography.sectionTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                        Text("Re-capture the same rooms later with checklist and export.")
                            .font(MoveMarkTheme.Typography.subheadline)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func roomRow(index: Int, room: RoomRecord) -> some View {
        let isComplete = !room.evidence.isEmpty
        let isNext = nextRoom?.id == room.id
        let photoCount = room.evidence.reduce(0) { $0 + $1.photoCount }
        let issueCount = room.evidence.flatMap(\.issueTags).count

        return Button {
            path.append(.roomDetail(roomID: room.id))
        } label: {
            MMCard(tone: .quiet, padding: 14, spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                isNext && !isComplete
                                    ? MoveMarkTheme.Colors.accent.opacity(0.16)
                                    : Color.white.opacity(0.05)
                            )
                            .frame(width: 34, height: 34)

                        Text("\(index)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(
                                isNext && !isComplete
                                    ? MoveMarkTheme.Colors.accent
                                    : MoveMarkTheme.Colors.textSecondary
                            )
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(room.name)
                                .font(MoveMarkTheme.Typography.sectionTitle)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                            if isNext && !isComplete {
                                MMPill(text: "Next", tone: .warning)
                            }
                        }

                        if isComplete {
                            let parts: [String] =
                                (photoCount > 0 ? ["\(photoCount) photos"] : [])
                                + (issueCount > 0 ? ["\(issueCount) \(issueCount == 1 ? "issue" : "issues")"] : [])

                            Text(parts.isEmpty ? "Ready to review" : parts.joined(separator: " · "))
                                .font(MoveMarkTheme.Typography.footnote)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                .lineLimit(2)
                        } else {
                            Text("Not started")
                                .font(MoveMarkTheme.Typography.footnote)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isComplete ? "checkmark.circle.fill" : "chevron.right")
                        .font(.system(size: isComplete ? 20 : 14, weight: .medium))
                        .foregroundStyle(
                            isComplete
                                ? MoveMarkTheme.Colors.primary
                                : MoveMarkTheme.Colors.textSecondary
                        )
                }
                .frame(minHeight: 56)
            }
        }
        .buttonStyle(.plain)
    }

    private func handleMoveInExportTap() {
        guard !rooms.isEmpty else { return }
        guard completedCount > 0 else { return }
        guard subscriptionManager.canExportMoveIn(forUser: sessionManager.userId) else {
            activePaywallReason = .unlimitedExports
            showPaywall = true
            return
        }
        exportMoveInReport()
    }

    private var moveInExportFootnote: String {
        if rooms.isEmpty {
            return "Add rooms to Walkthrough first"
        }
        if completedCount == 0 {
            return "Capture room proof before exporting"
        }
        if subscriptionManager.hasPro {
            return "Included with Pro"
        }
        if subscriptionManager.canExportMoveIn(forUser: sessionManager.userId) {
            return subscriptionManager.remainingFreeMoveInExportsText(forUser: sessionManager.userId)
        }
        return "Upgrade for additional move-in exports"
    }

    private func exportMoveInReport() {
        guard let property = propertyStore.currentProperty else { return }
        guard !isExporting else { return }
        guard
            let baseURL = Bundle.main.object(forInfoDictionaryKey: "MoveMarkAPIBaseURL") as? String,
            !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            errorMessage = "API base URL is missing. Set MoveMarkAPIBaseURL in build settings."
            lastErrorFromExport = true
            return
        }

        isExporting = true
        errorMessage = nil
        exportSuccessBanner = nil

        Task { @MainActor in
            defer { isExporting = false }

            do {
                let session = try await supabase.auth.session
                let apiClient = try ExportAPIClient(baseURLString: baseURL)
                _ = try await apiClient.requestMoveInExport(
                    propertyId: property.id,
                    accessToken: session.accessToken
                )

                if !subscriptionManager.hasPro, let uid = sessionManager.userId {
                    subscriptionManager.incrementFreeMoveInExportCount(forUser: uid)
                }

                lastErrorFromExport = false
                exportSuccessBanner = MoveMarkFlowMessage.exportQueuedHint
                MMHaptics.success()
            } catch {
                exportSuccessBanner = nil
                errorMessage = userFacingExportError(from: error)
                lastErrorFromExport = true
            }
        }
    }

    private func userFacingExportError(from error: Error) -> String {
        let lower = error.localizedDescription.lowercased()
        if lower.contains("property not found") {
            return "Couldn’t queue export for this property. Refresh and try again."
        }
        return MoveMarkFlowMessage.exportOrAPIFailed(
            error,
            fallback: "Couldn’t queue move-in export. Try again.",
            intent: .mutate
        )
    }
}

private struct AddRoomSheetView: View {
    let onDismiss: () -> Void
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var roomName = ""
    @State private var isAdding = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MMTextField(
                title: "Room name",
                placeholder: "e.g. Office, Hallway, Balcony",
                text: $roomName
            )

            if let errorMessage {
                MMErrorBanner(
                    message: errorMessage,
                    retryTitle: MMCopy.tryAgain,
                    onRetry: { submit() }
                )
            }

            ZStack {
                MMButton(
                    title: isAdding ? "Adding…" : "Add room",
                    action: { submit() },
                    kind: .primary,
                    size: .standard,
                    isDisabled: isAdding
                )
                .opacity(isAdding ? 0.6 : 1.0)

                if isAdding {
                    ProgressView()
                        .tint(MoveMarkTheme.Colors.primary)
                }
            }
        }
        .padding(MoveMarkTheme.Spacing.screenHorizontal)
    }

    private func submit() {
        guard let property = propertyStore.currentProperty else {
            errorMessage = MoveMarkFlowMessage.noActiveProperty
            return
        }

        guard let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.signInRequired
            return
        }

        let name = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Enter a room name."
            return
        }

        guard !isAdding else { return }

        isAdding = true
        errorMessage = nil

        Task { @MainActor in
            defer { isAdding = false }
            do {
                try await propertyStore.addRoom(named: name, propertyId: property.id, userId: userId)
                onDismiss()
            } catch {
                errorMessage = MoveMarkFlowMessage.roomAddFailed(error)
            }
        }
    }
}
