//
//  RoomListView.swift
//  movemork
//
//  MoveMark — Proof Sprint. Rooms are the only progress model; lease, deposit and
//  maintenance sit after the rooms as supporting proof and never count toward
//  "rooms documented".
//

import SwiftUI

struct RoomListView: View {
    @Binding var path: [AppRoute]
    @Environment(PropertyStore.self) private var propertyStore

    @State private var showAddRoom = false
    @State private var roomsListAppeared = false

    private var rooms: [RoomRecord] {
        propertyStore.currentProperty?.rooms ?? []
    }

    private var completedCount: Int {
        rooms.filter { MMRoomProofMetrics.isDocumented($0) }.count
    }

    private var progress: Double {
        guard !rooms.isEmpty else { return 0 }
        return Double(completedCount) / Double(rooms.count)
    }

    private var nextRoom: RoomRecord? {
        rooms.first(where: { !MMRoomProofMetrics.isDocumented($0) })
    }

    private var allRoomsDocumented: Bool {
        !rooms.isEmpty && completedCount >= rooms.count
    }

    var body: some View {
        ZStack {
            Color.clear
                .mmProofShellBackground(heroFocus: true, ctaBloom: true)

            ScrollView {
                VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.sectionGap) {
                    progressCard

                    roomsSection

                    supportingProofSection

                    moveInReportSection

                    MMSignedInScrollTailSpacer(kind: .focusedSignedIn)
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
        .navigationTitle("Proof Sprint")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddRoom = true
                } label: {
                    Label("Room", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .font(MoveMarkTheme.Typography.footnoteEmphasis)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(Capsule().stroke(MoveMarkTheme.Stroke.interactive, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add room")
            }
        }
        .sheet(isPresented: $showAddRoom) {
            AddRoomSheetView(onDismiss: { showAddRoom = false })
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
                .presentationBackground(MoveMarkTheme.Colors.appBackground)
                .mmSheetEntrance(isPresented: showAddRoom)
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let propertyTitle = propertyStore.currentProperty?.title.trimmingCharacters(in: .whitespacesAndNewlines),
               !propertyTitle.isEmpty,
               !rooms.isEmpty
            {
                Text(propertyTitle)
                    .font(MoveMarkTheme.Typography.heroTitle)
                    .tracking(-0.4)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            }

            if !rooms.isEmpty {
                MMRoomProgressCard(
                    headline: "\(completedCount) of \(rooms.count) rooms documented",
                    nextLine: progressNextLine,
                    progress: progress,
                    primaryTitle: progressPrimaryTitle,
                    onPrimary: openNextRoom,
                    documentedCount: completedCount,
                    totalCount: rooms.count
                )
            }

            if rooms.isEmpty {
                MMMissingItemCard(
                    title: "Add your first room",
                    message: "Start with the room you are in — Kitchen works well.",
                    actionTitle: MMNextBestAction.addRoom.title,
                    onAction: { showAddRoom = true }
                )
            }
        }
    }

    private var progressNextLine: String {
        if allRoomsDocumented {
            return "All rooms documented"
        }
        if let nextRoom {
            return "Next: \(nextRoom.name)"
        }
        return "Add a room to start."
    }

    private var progressPrimaryTitle: String {
        if allRoomsDocumented {
            return "Review your rooms"
        }
        if let nextRoom {
            return "Capture \(nextRoom.name)"
        }
        return MMNextBestAction.addRoom.title
    }

    private func openNextRoom() {
        if let nextRoom {
            path.append(.roomDetail(roomID: nextRoom.id))
        } else if let first = rooms.first {
            path.append(.roomDetail(roomID: first.id))
        }
    }

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.cardGap) {
            MMSectionLabel("Rooms") {
                if !rooms.isEmpty {
                    Text("\(completedCount) of \(rooms.count)")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
            }

            if rooms.isEmpty {
                MMEmptyState(
                    systemImage: "door.left.hand.open",
                    title: "Start move-in proof",
                    message: "Add rooms, then photograph walls, floors, and anything already damaged."
                )
            }

            VStack(spacing: 8) {
                ForEach(Array(rooms.enumerated()), id: \.element.id) { idx, room in
                    roomProofRow(index: idx + 1, room: room)
                        .mmStaggeredAppear(isVisible: roomsListAppeared, index: idx)
                }
            }
        }
    }

    private func roomProofRow(index: Int, room: RoomRecord) -> some View {
        let photoCount = MMRoomProofMetrics.photoCount(for: room)
        let issueCount = MMRoomProofMetrics.issueCount(for: room)
        let isNext = nextRoom?.id == room.id
        let status = MMRoomProofStatus.resolve(
            photoCount: photoCount,
            issueCount: issueCount,
            isNext: isNext
        )

        return MMRoomProofRow(
            index: index,
            roomName: room.name,
            status: status,
            showsNextBadge: isNext && photoCount == 0,
            onTap: { path.append(.roomDetail(roomID: room.id)) }
        )
    }

    /// Lease, deposit and maintenance — shown after rooms, outside the room count.
    @ViewBuilder
    private var supportingProofSection: some View {
        if let property = propertyStore.currentProperty {
            let issues = propertyStore.openIssueCount(for: property)
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.cardGap) {
                MMSectionLabel("Supporting proof")

                ForEach(ProofSprint.documentTargets) { target in
                    let added = ProofSprint.isDocumentUploaded(target.documentType, in: property)
                    ProofTaskCard(
                        title: target.title,
                        reason: added ? "Saved to your vault" : target.reason,
                        action: { path.append(.vaultDetail(propertyId: property.id)) },
                        statusLabel: added ? "Added" : "Needed",
                        statusTone: added ? .success : .warning
                    )
                }

                ProofTaskCard(
                    title: "Maintenance issues",
                    reason: issues == 0
                        ? "Timestamp repairs and problems."
                        : (issues == 1 ? "1 open issue" : "\(issues) open issues"),
                    action: { path.append(.maintenance) },
                    statusLabel: issues > 0 ? "\(issues) open" : nil,
                    statusTone: .neutral
                )

                ProofTaskCard(
                    title: "Move-out proof",
                    reason: "Re-capture the same rooms when you leave.",
                    action: { path.append(.moveOut) }
                )
            }
        }
    }

    @ViewBuilder
    private var moveInReportSection: some View {
        if !rooms.isEmpty {
            let remaining = rooms.count - completedCount
            VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.cardGap) {
                MMSectionLabel("Move-in report")

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(completedCount) of \(rooms.count) rooms documented")
                            .font(MoveMarkTheme.Typography.rowTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                        Text(reportGuidance(remaining: remaining))
                            .font(MoveMarkTheme.Typography.metadata)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    MMButton(
                        title: "View reports",
                        action: { path.append(.exports) },
                        kind: .secondary,
                        size: .inline
                    )
                }
                .padding(MoveMarkTheme.Spacing.panelPadding)
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

    private func reportGuidance(remaining: Int) -> String {
        if remaining <= 0 { return "Every room is documented. Your report is ready to make." }
        if completedCount == 0 { return "Document a room to make your first report." }
        let rooms = remaining == 1 ? "1 room still needs proof" : "\(remaining) rooms still need proof"
        return "A report can already be made — \(rooms)."
    }
}

private struct AddRoomSheetView: View {
    let onDismiss: () -> Void
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var roomName = ""
    @State private var isAdding = false
    @State private var errorMessage: String? = nil

    private let suggestedRoomNames = [
        "Office", "Hallway", "Balcony", "Storage", "Den",
    ]

    private var trimmedName: String {
        roomName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedName.isEmpty && !isAdding
    }

    var body: some View {
        ScrollView {
            sheetContent
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .background(MoveMarkTheme.Colors.appBackground)
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add a room")
                        .font(MoveMarkTheme.Typography.sectionTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("Add any space you want documented before move-in.")
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button("Cancel", action: onDismiss)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
            }

            MMTextField(
                title: "Room name",
                placeholder: "Office",
                text: $roomName
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Suggested rooms")
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                FlowLayout(spacing: 8) {
                    ForEach(suggestedRoomNames, id: \.self) { name in
                        suggestionChip(name)
                    }
                }
            }

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
                    isDisabled: !canSubmit
                )
                .opacity(isAdding ? 0.6 : 1.0)

                if isAdding {
                    ProgressView()
                        .tint(MoveMarkTheme.Colors.primary)
                }
            }
        }
        .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
        .padding(.top, 28)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private func suggestionChip(_ name: String) -> some View {
        let isSelected = trimmedName.caseInsensitiveCompare(name) == .orderedSame

        Button {
            roomName = name
        } label: {
            Text(name)
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(
                    isSelected
                        ? MoveMarkTheme.Colors.textPrimary
                        : MoveMarkTheme.Colors.textSecondary.opacity(0.76)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                                ? MoveMarkTheme.Colors.primary.opacity(0.18)
                                : MoveMarkTheme.Colors.card.opacity(0.92)
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.14 : 0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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

        guard !trimmedName.isEmpty else { return }
        guard !isAdding else { return }

        isAdding = true
        errorMessage = nil

        Task { @MainActor in
            defer { isAdding = false }
            do {
                try await propertyStore.addRoom(named: trimmedName, propertyId: property.id, userId: userId)
                onDismiss()
            } catch {
                errorMessage = MoveMarkFlowMessage.roomAddFailed(error)
            }
        }
    }
}
