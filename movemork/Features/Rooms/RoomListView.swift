//
//  RoomListView.swift
//  movemork
//
//  MoveMark — Room proof: next room, documented rooms, locked report hint.
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
                VStack(alignment: .leading, spacing: 22) {
                    roomProofHeader

                    progressCard

                    roomsSection

                    moveInReportCard

                    moveOutLink

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
            AddRoomSheetView(onDismiss: { showAddRoom = false })
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
                .presentationBackground(MoveMarkTheme.Colors.appBackground)
                .mmSheetEntrance(isPresented: showAddRoom)
        }
    }

    private var roomProofHeader: some View {
        MMRenterHeader(
            title: "Room proof",
            subtitle: "Mark old damage before move-in."
        )
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let propertyTitle = propertyStore.currentProperty?.title.trimmingCharacters(in: .whitespacesAndNewlines),
               !propertyTitle.isEmpty,
               !rooms.isEmpty
            {
                Text(propertyTitle)
                    .font(MoveMarkTheme.Typography.cardTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            }

            if !rooms.isEmpty {
                MMRoomProgressCard(
                    headline: "\(completedCount) of \(rooms.count) rooms documented",
                    nextLine: progressNextLine,
                    progress: progress,
                    primaryTitle: progressPrimaryTitle,
                    onPrimary: openNextRoom
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rooms")
                    .font(MoveMarkTheme.Typography.caption)
                    .tracking(1.0)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                Spacer()

                if !rooms.isEmpty {
                    Text("\(completedCount) of \(rooms.count) ready")
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

    private var moveInReportCard: some View {
        MMCard(tone: .quiet, padding: 16, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Move-in report")
                    .font(MoveMarkTheme.Typography.sectionTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text(
                    allRoomsDocumented
                        ? "Open the Reports tab to make your move-in report."
                        : "Unlocks after all rooms have photos."
                )
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                if !rooms.isEmpty {
                    Text("\(completedCount) of \(rooms.count) rooms documented")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
            }
        }
    }

    private var moveOutLink: some View {
        MMProofListRow(
            title: "Move-out proof",
            subtitle: "Re-capture the same rooms when you leave.",
            onTap: { path.append(.moveOut) }
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
                    .font(.system(size: 15, weight: .medium))
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
