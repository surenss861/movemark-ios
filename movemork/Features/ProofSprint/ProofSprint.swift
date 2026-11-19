//
//  ProofSprint.swift
//  movemork
//
//  Move-in proof guidance — supporting documents and per-room shot prompts. Room
//  progress itself comes from the property's own rooms, not a fixed target list.
//

import Foundation

enum ProofSprint {
    static let documentTargets: [DocumentTarget] = [
        .init(title: "Lease agreement", documentType: .lease, reason: "Ties your proof to the right rental."),
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

    struct DocumentTarget: Identifiable, Equatable {
        let title: String
        let documentType: VaultDocumentType
        let reason: String
        var id: String { documentType.rawValue }
    }

    static func isDocumentUploaded(_ type: VaultDocumentType, in property: PropertyRecord) -> Bool {
        let keys = DocumentRepository.documentTypeQueryKeys(type.rawValue)
        return keys.contains { property.vaultDocuments.contains($0) }
    }
}
