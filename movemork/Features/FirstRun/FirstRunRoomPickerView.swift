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
        case .bedroom: return "Bedroom"
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                MMRenterHeader(
                    title: moment.roomTitle,
                    subtitle: moment.roomSubtitle
                )

                VStack(spacing: 10) {
                    ForEach(FirstRunRoomOption.allCases) { option in
                        roomOptionRow(option)
                    }
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(.red.opacity(0.9))
                }

                ZStack {
                    MMButton(
                        title: "Start room proof",
                        action: { startRoomProof() },
                        kind: .primary,
                        size: .auth,
                        isDisabled: isLoading
                    )
                    .opacity(isLoading ? 0.6 : 1)

                    if isLoading {
                        ProgressView()
                            .tint(MoveMarkTheme.Colors.primary)
                    }
                }
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .mmProofShellBackground(heroFocus: false, ctaBloom: false)
        .sheet(isPresented: $showOtherSheet) {
            otherRoomSheet
        }
        .task(id: propertyId) {
            await ensurePropertyLoaded()
        }
    }

    private func roomOptionRow(_ option: FirstRunRoomOption) -> some View {
        let isSelected = selected == option
        return Button {
            MMHaptics.selection()
            selected = option
        } label: {
            HStack {
                Text(option.title)
                    .font(MoveMarkTheme.Typography.bodySmallEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(MoveMarkTheme.Typography.subtitleLarge)
                    .foregroundStyle(
                        isSelected
                            ? MoveMarkTheme.Colors.primary
                            : MoveMarkTheme.Colors.textSecondary.opacity(0.45)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected
                            ? MoveMarkTheme.Colors.primary.opacity(0.12)
                            : MoveMarkTheme.Colors.card.opacity(0.92)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected
                            ? MoveMarkTheme.Colors.primary.opacity(0.45)
                            : MoveMarkTheme.Colors.cardStroke.opacity(0.45),
                        lineWidth: 0.75
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var otherRoomSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Name this room")
                    .font(MoveMarkTheme.Typography.cardTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                MMTextField(
                    title: "Room name",
                    placeholder: "e.g. Office",
                    text: $otherRoomName,
                    density: .authCompact
                )

                MMButton(
                    title: "Use this room",
                    action: {
                        showOtherSheet = false
                        startRoomProof()
                    },
                    kind: .primary,
                    size: .standard,
                    isDisabled: otherRoomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Spacer()
            }
            .padding(20)
            .navigationTitle("Other room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showOtherSheet = false }
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                }
            }
        }
        .presentationDetents([.medium])
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
                    errorMessage = "Couldn’t load your vault. Try again."
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
