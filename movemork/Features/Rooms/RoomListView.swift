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
    @State private var proofToast: MMProofToastMessage? = nil
    @State private var proofToastVisible = false
    @State private var roomsListAppeared = false

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
            Color.clear
                .mmProofShellBackground(heroFocus: true, ctaBloom: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    roomProofHeader

                    progressCard

                    MMProofTimeline(
                        title: "Proof trail",
                        rows: roomProofTrailRows,
                        highlightedRowID: highlightedRoomTrailRowID,
                        appeared: roomsListAppeared
                    )

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
                .padding(.top, 12)
                .mmScrollContentTopInset(2)
                .padding(.bottom, MoveMarkTheme.Spacing.scrollTailFocusedFlow)
            }
            .onAppear {
                roomsListAppeared = true
            }
        }
        .mmProofToast(message: proofToast, isVisible: proofToastVisible)
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(
                reason: activePaywallReason,
                onClose: { showPaywall = false }
            )
        }
        .navigationTitle("Room proof")
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

    private var roomProofTrailRows: [MMProofTimelineRow] {
        MMProofTimelineBuilder.roomProofTrail(rooms: rooms, nextRoom: nextRoom)
    }

    private var highlightedRoomTrailRowID: String? {
        guard let nextRoom else { return nil }
        return "room-\(nextRoom.id.uuidString)"
    }

    private var roomProofHeader: some View {
        MMEditorialHeader(
            eyebrow: "Move-in proof",
            title: "Rooms with evidence",
            subtitle: "Tag old damage in each room so it cannot be blamed on you later."
        )
    }

    private var progressCard: some View {
        VStack(spacing: 12) {
            if !rooms.isEmpty {
                MMProofHeroCard(
                    headline: "\(completedCount) of \(rooms.count) rooms ready",
                    nextLine: nextRoom.map { "Next: \($0.name)" } ?? "Review your rooms.",
                    progress: progress,
                    primaryTitle: MMNextBestActionMapper.roomProof(
                        roomsEmpty: false,
                        allRoomsDone: completedCount >= rooms.count,
                        hasNextRoom: nextRoom != nil
                    ).title,
                    onPrimary: {
                        if let nextRoom {
                            path.append(.roomDetail(roomID: nextRoom.id))
                        } else if let first = rooms.first {
                            path.append(.roomDetail(roomID: first.id))
                        }
                    },
                    style: .light
                )
            }

            if rooms.isEmpty {
                MMProofTaskCard(
                    systemImage: "door.left.hand.open",
                    title: "Add your first room",
                    message: "Start move-in proof for each room.",
                    actionTitle: MMNextBestAction.addRoom.title,
                    onAction: { showAddRoom = true }
                )
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
                    Text("\(completedCount) of \(rooms.count) rooms ready")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }

            if rooms.isEmpty {
                MMEmptyState(
                    systemImage: "door.left.hand.open",
                    title: "Start move-in proof",
                    message: "Add rooms, then photograph walls, floors, and anything already damaged."
                )
            }

            VStack(spacing: 10) {
                ForEach(Array(rooms.enumerated()), id: \.element.id) { idx, room in
                    roomRow(index: idx + 1, room: room)
                        .mmStaggeredAppear(isVisible: roomsListAppeared, index: idx)
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

                Text("Bundle room photos and damage tags into one report if your deposit is questioned.")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                MMButton(
                    title: isExporting ? "Making report…" : MMNextBestAction.makeReport.title,
                    action: handleMoveInExportTap,
                    kind: completedCount > 0 ? .primary : .secondary,
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

                        Text("Re-capture the same rooms later with checklist and reports.")
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
            MMCard(tone: .artifact, padding: 16, spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                isNext && !isComplete
                                    ? MoveMarkTheme.Colors.accent.opacity(0.16)
                                    : MoveMarkTheme.Colors.mint.opacity(0.55)
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

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(room.name)
                                .font(MoveMarkTheme.Typography.cardTitle)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                                .lineLimit(2)

                            if isNext && !isComplete {
                                MMPill(text: "Next", tone: .warning)
                            }
                        }

                        if isComplete {
                            let parts: [String] =
                                (photoCount > 0 ? ["\(photoCount) photos"] : [])
                                + (issueCount > 0 ? ["\(issueCount) \(issueCount == 1 ? "issue" : "issues")"] : [])

                            Text(parts.isEmpty ? "Ready to review" : parts.joined(separator: " · "))
                                .font(MoveMarkTheme.Typography.subheadline)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                .lineLimit(2)
                        } else {
                            Text("Not started — tap to capture proof")
                                .font(MoveMarkTheme.Typography.subheadline)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isComplete ? "checkmark.circle.fill" : "chevron.right")
                        .font(.system(size: isComplete ? 22 : 14, weight: .medium))
                        .foregroundStyle(
                            isComplete
                                ? MoveMarkTheme.Colors.semanticSuccess
                                : MoveMarkTheme.Colors.textSecondary
                        )
                }
                .frame(minHeight: 60)
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
            return "Add rooms first"
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
                exportSuccessBanner = nil
                MMProofToastPresenter.show(
                    .reportQueued(),
                    message: $proofToast,
                    isVisible: $proofToastVisible
                )
                NotificationCenter.default.post(name: .moveMarkExportsShouldRefresh, object: nil)
            } catch {
                exportSuccessBanner = nil
                errorMessage = userFacingExportError(from: error)
                lastErrorFromExport = true
                MMHaptics.error()
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
