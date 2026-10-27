//
//  RoomListView.swift
//  movemork
//
//  MoveMark — The rental's rooms as proof coverage: how many rooms are documented, the next room with the
//  one capture action, then every room with what it holds. Lease, deposit, maintenance, move-out and the
//  report sit after the rooms as supporting proof and never count toward "rooms documented". Adding a room
//  happens in its own sheet.
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

    private var nextRoom: RoomRecord? {
        rooms.first(where: { !MMRoomProofMetrics.isDocumented($0) })
    }

    private var headerSubtitle: String? {
        guard let property = propertyStore.currentProperty else { return nil }
        let title = PropertyVaultModel.displayTitle(for: property)
        return [title, PropertyVaultModel.addressLine(for: property)].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        MMScreen(eyebrow: "Move-in proof", title: "Rooms", subtitle: headerSubtitle, isPushed: true) {
            if rooms.isEmpty {
                MMEmptyBlock(
                    icon: "door.left.hand.open",
                    title: "No rooms yet",
                    message: "Add each room you'll document — start with the one you're standing in. Photos taken before you unpack become your move-in record.",
                    actionTitle: "Add a room",
                    action: { showAddRoom = true }
                )
            } else {
                MMProgressStrip(label: "Rooms documented", done: completedCount, total: rooms.count, unit: "rooms")
                    .padding(.horizontal, 4)
                MMRentalRoomsBlock(
                    rooms: rooms.map { MMRentalRoom($0) },
                    nextID: nextRoom?.id,
                    completeTitle: "Every room documented",
                    completeActionTitle: "Generate move-in report",
                    completeAction: { path.append(.exports) },
                    onCapture: openNextRoom,
                    onOpenRoom: { path.append(.roomDetail(roomID: $0)) },
                    onAddRoom: { showAddRoom = true }
                )
                .padding(.top, 18)
            }
            supportingProofSection
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

    private func openNextRoom() {
        if let nextRoom {
            path.append(.roomDetail(roomID: nextRoom.id))
        } else if let first = rooms.first {
            path.append(.roomDetail(roomID: first.id))
        }
    }

    /// Lease, deposit, maintenance, move-out and the report — after rooms, outside the room count.
    @ViewBuilder
    private var supportingProofSection: some View {
        if let property = propertyStore.currentProperty {
            let issues = propertyStore.openIssueCount(for: property)
            VStack(alignment: .leading, spacing: 10) {
                MMRecordSectionHeader(title: "Supporting proof")
                MMGroup(footer: "Supporting proof backs up your rooms; it doesn't count toward rooms documented.") {
                    ForEach(ProofSprint.documentTargets) { target in
                        let added = ProofSprint.isDocumentUploaded(target.documentType, in: property)
                        Button { path.append(.vaultDetail(propertyId: property.id)) } label: {
                            MMRecordRow(title: target.title, icon: PropertyVaultContent.recordIcon(target.documentType),
                                        isPresent: added, detail: added ? "to your rental record" : target.reason) {
                                MMRowChevron()
                            }
                        }
                        .buttonStyle(MMLightPressStyle())
                        .accessibilityElement(children: .combine)
                        MMRowDivider(leading: 52)
                    }
                    supportingRow(
                        title: "Maintenance log",
                        subtitle: issues == 0
                            ? "Record repairs and problems with photos and a date."
                            : (issues == 1 ? "1 open case" : "\(issues) open cases"),
                        icon: "wrench.and.screwdriver"
                    ) { path.append(.maintenance) }
                    MMRowDivider(leading: 52)
                    supportingRow(
                        title: "Move-out",
                        subtitle: "Compare move-in to move-out when you leave.",
                        icon: "arrow.2.circlepath"
                    ) { path.append(.moveOut) }
                    if !rooms.isEmpty && completedCount < rooms.count {
                        MMRowDivider(leading: 52)
                        supportingRow(
                            title: "Move-in report",
                            subtitle: reportGuidance(remaining: rooms.count - completedCount),
                            icon: "doc.richtext"
                        ) { path.append(.exports) }
                    }
                }
            }
            .padding(.top, 32)
        }
    }

    private func supportingRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MMStatusRow(title: title, subtitle: subtitle, icon: icon)
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityElement(children: .combine)
    }

    private func reportGuidance(remaining: Int) -> String {
        if completedCount == 0 { return "Document a room to make your first report." }
        let rooms = remaining == 1 ? "1 room still needs proof" : "\(remaining) rooms still need proof"
        return "Ready to make now — \(rooms)."
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

    private static let suggestedRoomNames = [
        "Kitchen", "Living Room", "Bedroom", "Bathroom", "Hallway", "Closet", "Laundry", "Balcony", "Office", "Storage",
    ]

    /// Suggestions the rental doesn't already have.
    private var suggestions: [String] {
        let existing = Set((propertyStore.currentProperty?.rooms ?? []).map { $0.name.lowercased() })
        return Self.suggestedRoomNames.filter { !existing.contains($0.lowercased()) }
    }

    private var trimmedName: String {
        roomName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedName.isEmpty && !isAdding
    }

    var body: some View {
        NavigationStack {
            MMSheetScaffold(title: "Add a room") {
                Text("Name the space. You'll photograph it next.")
                    .mmFont(15)
                    .foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                MMField(title: "Room name", placeholder: "e.g. Primary Bedroom", text: $roomName,
                        autocapitalization: .words, submitLabel: .done, onSubmit: { if canSubmit { submit() } })
                    .padding(.top, 18)

                if !suggestions.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.self) { name in
                            MMChip(title: name, isSelected: trimmedName.caseInsensitiveCompare(name) == .orderedSame) {
                                roomName = name
                            }
                            .fixedSize()
                        }
                    }
                    .padding(.top, 14)
                    .accessibilityLabel("Suggestions")
                }

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
