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

    private var headerTitle: String {
        let title = propertyStore.currentProperty?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "Rooms" : title
    }

    private var headerSubtitle: String {
        rooms.isEmpty
            ? "Document every room before you move in."
            : "\(completedCount) of \(rooms.count) rooms documented"
    }

    var body: some View {
        MMScreen(eyebrow: "Proof sprint", title: headerTitle, subtitle: headerSubtitle, isPushed: true) {
            if rooms.isEmpty {
                MMEmptyBlock(
                    icon: "door.left.hand.open",
                    title: "Add your first room",
                    message: "Start with the room you are in — Kitchen works well. Then photograph walls, floors, and anything already damaged.",
                    actionTitle: MMNextBestAction.addRoom.title,
                    action: { showAddRoom = true }
                )
            } else {
                progressPanel
                roomsSection.padding(.top, 30)
            }
            supportingProofSection
            moveInReportSection
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddRoom = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add room")
            }
        }
        .sheet(isPresented: $showAddRoom) {
            AddRoomSheetView(onDismiss: { showAddRoom = false })
                .presentationDetents([.height(460), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(MMInk.sheet)
                .mmSheetEntrance(isPresented: showAddRoom)
        }
    }

    /// The next room and the one capture action, with the count it moves.
    private var progressPanel: some View {
        MMPanel {
            if let nextRoom {
                Text("Next room").mmFont(12.5).foregroundStyle(MMInk.secondary)
                Text(nextRoom.name).mmFont(20, .semibold).foregroundStyle(MMInk.text).padding(.top, 2)
            } else {
                Text("Move-in proof").mmFont(12.5).foregroundStyle(MMInk.secondary)
                Text(progressNextLine).mmFont(20, .semibold).foregroundStyle(MMInk.text).padding(.top, 2)
            }
            MMProgressLine(fraction: progress).padding(.top, 12)
            Text("\(completedCount) of \(rooms.count) rooms documented")
                .mmFont(13).monospacedDigit().foregroundStyle(MMInk.secondary)
                .padding(.top, 10)
            MMPrimaryButton(title: progressPrimaryTitle, icon: nextRoom != nil ? "camera.fill" : nil) {
                MMHaptics.soft()
                openNextRoom()
            }
            .padding(.top, 16)
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
            HStack(alignment: .firstTextBaseline) {
                MMSectionTitle(title: "Rooms")
                Text("\(completedCount) of \(rooms.count)")
                    .mmFont(13).monospacedDigit().foregroundStyle(MMInk.secondary)
            }
            MMGroup {
                ForEach(Array(rooms.enumerated()), id: \.element.id) { idx, room in
                    if idx > 0 { MMRowDivider(leading: 52) }
                    roomProofRow(room: room)
                }
            }
        }
    }

    private func roomProofRow(room: RoomRecord) -> some View {
        let photoCount = MMRoomProofMetrics.photoCount(for: room)
        let issueCount = MMRoomProofMetrics.issueCount(for: room)
        let isNext = nextRoom?.id == room.id
        let state: MMRoomRow.RoomState = photoCount > 0 ? .documented : (isNext ? .next : .todo)
        // The check says "documented"; the line says what the room holds.
        let detail = photoCount > 0
            ? MMProofTimelineBuilder.photoIssueLine(photos: photoCount, issues: issueCount)
            : "Needs proof"

        return Button {
            path.append(.roomDetail(roomID: room.id))
        } label: {
            MMRoomRow(name: room.name, detail: detail, state: state)
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityElement(children: .combine)
    }

    /// Lease, deposit and maintenance — shown after rooms, outside the room count.
    @ViewBuilder
    private var supportingProofSection: some View {
        if let property = propertyStore.currentProperty {
            let issues = propertyStore.openIssueCount(for: property)
            VStack(alignment: .leading, spacing: 12) {
                MMSectionTitle(title: "Supporting proof")
                MMGroup {
                    ForEach(ProofSprint.documentTargets) { target in
                        let added = ProofSprint.isDocumentUploaded(target.documentType, in: property)
                        supportingRow(
                            title: target.title,
                            subtitle: added ? "Saved to your vault" : target.reason,
                            icon: added ? "doc.text.fill" : "doc.text",
                            status: added ? "Added" : "Needed",
                            tone: added ? .done : .needed
                        ) { path.append(.vaultDetail(propertyId: property.id)) }
                        MMRowDivider(leading: 52)
                    }
                    supportingRow(
                        title: "Maintenance issues",
                        subtitle: issues == 0
                            ? "Timestamp repairs and problems."
                            : (issues == 1 ? "1 open issue" : "\(issues) open issues"),
                        icon: "wrench.and.screwdriver",
                        status: issues > 0 ? "\(issues) open" : nil,
                        tone: .neutral
                    ) { path.append(.maintenance) }
                    MMRowDivider(leading: 52)
                    supportingRow(
                        title: "Move-out proof",
                        subtitle: "Re-capture the same rooms when you leave.",
                        icon: "arrow.2.circlepath"
                    ) { path.append(.moveOut) }
                }
            }
            .padding(.top, 30)
        }
    }

    private func supportingRow(title: String, subtitle: String, icon: String, status: String? = nil,
                               tone: MMRowStatusTone = .neutral, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MMStatusRow(title: title, subtitle: subtitle, icon: icon, status: status, tone: tone)
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var moveInReportSection: some View {
        if !rooms.isEmpty {
            let remaining = rooms.count - completedCount
            VStack(alignment: .leading, spacing: 12) {
                MMSectionTitle(title: "Move-in report")
                MMGroup {
                    supportingRow(
                        title: "View reports",
                        subtitle: reportGuidance(remaining: remaining),
                        icon: "doc.richtext"
                    ) { path.append(.exports) }
                }
            }
            .padding(.top, 30)
        }
    }

    private func reportGuidance(remaining: Int) -> String {
        if remaining <= 0 { return "Every room is documented. Your report is ready to make." }
        if completedCount == 0 { return "Document a room to make your first report." }
        let rooms = remaining == 1 ? "1 room still needs proof" : "\(remaining) rooms still need proof"
        return "A report can already be made — \(rooms)."
    }
}

struct AddRoomSheetView: View {
    let onDismiss: () -> Void
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var roomName = ""
    @State private var isAdding = false
    @State private var errorMessage: String? = nil

    init(onDismiss: @escaping () -> Void, roomName: String = "", errorMessage: String? = nil) {
        self.onDismiss = onDismiss
        _roomName = State(initialValue: roomName)
        _errorMessage = State(initialValue: errorMessage)
    }

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
        NavigationStack {
            MMSheetScaffold(title: "Add a room") {
                Text("Add any space you want documented before move-in.")
                    .mmFont(15)
                    .foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                MMField(title: "Room name", placeholder: "Office", text: $roomName)
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggested").mmFont(13, .medium).foregroundStyle(MMInk.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(suggestedRoomNames, id: \.self) { name in
                            MMChip(title: name, isSelected: trimmedName.caseInsensitiveCompare(name) == .orderedSame) {
                                roomName = name
                            }
                            .fixedSize()
                        }
                    }
                }
                .padding(.top, 18)

                if let errorMessage {
                    MMNotice(message: errorMessage, actionTitle: MMCopy.tryAgain, action: { submit() })
                        .padding(.top, 18)
                }

                MMPrimaryButton(title: isAdding ? "Adding…" : "Add room", isLoading: isAdding, isDisabled: !canSubmit) {
                    submit()
                }
                .padding(.top, 22)
            }
            .scrollBounceBehavior(.basedOnSize)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
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
