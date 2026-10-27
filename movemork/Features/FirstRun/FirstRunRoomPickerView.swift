//
//  FirstRunRoomPickerView.swift
//  movemork
//

import SwiftUI

enum FirstRunRoomOption: String, CaseIterable, Identifiable {
    case kitchen
    case livingRoom
    case bedroom
    case bathroom
    case hallway
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kitchen: return "Kitchen"
        case .livingRoom: return "Living room"
        case .bedroom: return "Primary bedroom"
        case .bathroom: return "Bathroom"
        case .hallway: return "Hallway"
        case .other: return "Other"
        }
    }

    /// Matches default rooms seeded at property creation.
    var defaultRoomName: String? {
        switch self {
        case .kitchen: return "Kitchen"
        case .livingRoom: return "Living Room"
        case .bedroom: return "Primary Bedroom"
        case .bathroom: return "Bathroom"
        case .hallway: return "Hallway"
        case .other: return nil
        }
    }
}

struct FirstRunRoomPickerView: View {
    let propertyId: UUID
    var moment: RentalMoment = .justMovedIn
    let onStartProof: (UUID, String) -> Void

    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var selected: FirstRunRoomOption = .kitchen
    @State private var otherRoomName = ""
    @State private var showOtherSheet = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        MMScreen(title: MoveMarkGrowthCopy.firstRunRoomTitle, subtitle: MoveMarkGrowthCopy.firstRunRoomSubtitle) {
            MMGroup {
                ForEach(Array(FirstRunRoomOption.allCases.enumerated()), id: \.element) { index, option in
                    if index > 0 { MMRowDivider() }
                    roomOptionRow(option)
                }
            }

            if !errorMessage.isEmpty {
                MMNotice(message: errorMessage)
                    .padding(.top, 22)
            }

            MMPrimaryButton(title: "Start room proof", isLoading: isLoading) { startRoomProof() }
                .accessibilityIdentifier("firstRun.startRoomProof")
                .padding(.top, 26)
        }
        .sheet(isPresented: $showOtherSheet) {
            otherRoomSheet
        }
        .task(id: propertyId) {
            await ensurePropertyLoaded()
        }
    }

    private func roomOptionRow(_ option: FirstRunRoomOption) -> some View {
        MMSelectRow(title: option.title, isSelected: selected == option) {
            MMHaptics.selection()
            selected = option
        }
    }

    private var otherRoomSheet: some View {
        NavigationStack {
            FirstRunOtherRoomSheet(otherRoomName: $otherRoomName) {
                showOtherSheet = false
                startRoomProof()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showOtherSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func ensurePropertyLoaded() async {
        guard propertyStore.currentProperty?.id != propertyId,
              let userId = sessionManager.userId else { return }
        await propertyStore.selectProperty(id: propertyId, userId: userId)
    }

    private func startRoomProof() {
        if selected == .other {
            let trimmed = otherRoomName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                showOtherSheet = true
                return
            }
        }

        guard !isLoading else { return }
        guard let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.signInRequired
            return
        }

        isLoading = true
        errorMessage = ""

        Task { @MainActor in
            defer { isLoading = false }
            do {
                if propertyStore.currentProperty?.id != propertyId {
                    await propertyStore.selectProperty(id: propertyId, userId: userId)
                }
                guard let property = propertyStore.currentProperty, property.id == propertyId else {
                    errorMessage = "Couldn’t open your rental record. Try again."
                    return
                }

                let (roomId, roomName) = try await resolveRoom(
                    option: selected,
                    property: property,
                    userId: userId
                )
                MMHaptics.success()
                onStartProof(roomId, roomName)
            } catch {
                errorMessage = error.localizedDescription
                MMHaptics.error()
            }
        }
    }

    private func resolveRoom(
        option: FirstRunRoomOption,
        property: PropertyRecord,
        userId: UUID
    ) async throws -> (UUID, String) {
        if option == .other {
            let name = otherRoomName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw NSError(domain: "FirstRun", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enter a room name."]) }
            if let existing = property.rooms.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                return (existing.id, existing.name)
            }
            try await propertyStore.addRoom(named: name, propertyId: property.id, userId: userId)
            await propertyStore.selectProperty(id: property.id, userId: userId)
            guard let room = propertyStore.currentProperty?.rooms.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
                throw NSError(domain: "FirstRun", code: 2, userInfo: [NSLocalizedDescriptionKey: "Couldn’t add that room. Try again."])
            }
            return (room.id, room.name)
        }

        guard let targetName = option.defaultRoomName else {
            throw NSError(domain: "FirstRun", code: 3, userInfo: [NSLocalizedDescriptionKey: "Pick a room to continue."])
        }

        if let room = property.rooms.first(where: { $0.name.caseInsensitiveCompare(targetName) == .orderedSame }) {
            return (room.id, room.name)
        }

        try await propertyStore.addRoom(named: targetName, propertyId: property.id, userId: userId)
        await propertyStore.selectProperty(id: property.id, userId: userId)
        guard let room = propertyStore.currentProperty?.rooms.first(where: { $0.name.caseInsensitiveCompare(targetName) == .orderedSame }) else {
            throw NSError(domain: "FirstRun", code: 4, userInfo: [NSLocalizedDescriptionKey: "Couldn’t open \(targetName). Try again."])
        }
        return (room.id, room.name)
    }
}

extension FirstRunRoomPickerView {
    /// Snapshot tests only: open on a given selection, optionally with an error showing. In an extension so
    /// the memberwise init the flow uses stays as it is.
    init(propertyId: UUID, moment: RentalMoment = .justMovedIn, previewSelection: FirstRunRoomOption, previewError: String = "") {
        self.init(propertyId: propertyId, moment: moment, onStartProof: { _, _ in })
        _selected = State(initialValue: previewSelection)
        _errorMessage = State(initialValue: previewError)
    }
}

/// The "Other" room sheet: name the room, then go straight into its capture.
struct FirstRunOtherRoomSheet: View {
    @Binding var otherRoomName: String
    let onUse: () -> Void

    private static let examples = ["Office", "Balcony", "Laundry", "Storage"]

    private var isNameEmpty: Bool {
        otherRoomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        MMSheetScaffold(title: "Add another room") {
            MMField(title: "Room name", placeholder: "Office", text: $otherRoomName,
                    autocapitalization: .words, accessibilityID: "firstRun.otherRoomName",
                    submitLabel: .done, onSubmit: { if !isNameEmpty { onUse() } })
                .autocorrectionDisabled()
                .padding(.top, 8)

            Text(Self.examples.joined(separator: " · "))
                .mmFont(13)
                .foregroundStyle(MMInk.secondary)
                .padding(.top, 8)
                .padding(.leading, 2)
                .accessibilityLabel("For example: \(Self.examples.joined(separator: ", "))")

            MMPrimaryButton(title: "Add room", isDisabled: isNameEmpty, action: onUse)
                .accessibilityIdentifier("firstRun.addOtherRoom")
                .padding(.top, 22)
        }
    }
}
