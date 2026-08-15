//
//  ProofSprint.swift
//  movemork
//
//  Guided move-in proof checklist — reduces “what should I photograph?” friction.
//

import Foundation

enum ProofSprint {
    static let title = "Move-in Proof Sprint"
    static let estimatedTimeLine = "Estimated time: 10–15 minutes"
    static let subtitle = "Document each space before you unpack. We’ll turn it into shareable proof."

    /// Ordered room targets for a typical apartment move-in.
    static let roomTargets: [RoomTarget] = [
        .init(title: "Living room", matchNames: ["Living Room", "Living room", "Lounge"]),
        .init(title: "Kitchen", matchNames: ["Kitchen"]),
        .init(title: "Bathroom", matchNames: ["Bathroom", "Primary Bathroom"]),
        .init(title: "Bedroom", matchNames: ["Primary Bedroom", "Bedroom", "Master Bedroom"]),
        .init(title: "Entry / hallway", matchNames: ["Hallway", "Entry", "Entrance", "Foyer"]),
    ]

    static let documentTargets: [DocumentTarget] = [
        .init(title: "Lease", documentType: .lease, reason: "Ties your proof to the right rental."),
        .init(title: "Deposit receipt", documentType: .depositReceipt, reason: "Helps if your deposit is questioned later."),
    ]

    /// Shot prompts shown while capturing any room during move-in.
    static let roomShotPrompts: [String] = [
        "Take a wide room photo",
        "Photograph walls and baseboards",
        "Photograph floors",
        "Photograph windows / blinds",
        "Tag visible damage",
        "Add notes for anything already wrong",
    ]

    struct RoomTarget: Identifiable, Equatable {
        let title: String
        let matchNames: [String]
        var id: String { title }
    }

    struct DocumentTarget: Identifiable, Equatable {
        let title: String
        let documentType: VaultDocumentType
        let reason: String
        var id: String { documentType.rawValue }
    }

    static func matchingRoom(for target: RoomTarget, in rooms: [RoomRecord]) -> RoomRecord? {
        rooms.first { room in
            matchNamesContains(target.matchNames, roomName: room.name)
        }
    }

    static func isRoomDocumented(_ room: RoomRecord) -> Bool {
        MMRoomProofMetrics.isDocumented(room)
    }

    static func isDocumentUploaded(_ type: VaultDocumentType, in property: PropertyRecord) -> Bool {
        let keys = DocumentRepository.documentTypeQueryKeys(type.rawValue)
        return keys.contains { property.vaultDocuments.contains($0) }
    }

    private static func matchNamesContains(_ names: [String], roomName: String) -> Bool {
        names.contains { $0.caseInsensitiveCompare(roomName) == .orderedSame }
    }
}
