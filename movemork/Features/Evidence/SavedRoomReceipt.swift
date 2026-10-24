//
//  SavedRoomReceipt.swift
//  movemork
//
//  What a room save produced, for the receipt that follows every save — and the one next step it offers.
//

import SwiftUI

struct SavedRoomReceipt: Identifiable {
    enum Next: Equatable {
        case room(UUID)   // another room still needs proof
        case report       // every room has proof
        case retry        // some photos didn't save
        case done
    }

    enum Action { case primary, viewEvidence, addMore }

    let id = UUID()
    let propertyId: UUID?
    let roomName: String
    let phaseLabel: String
    let photoCount: Int
    let pendingCount: Int
    let issueCount: Int
    let savedAt: Date
    let next: Next

    var primaryActionLabel: String {
        switch next {
        case .room: return "Continue to next room"
        case .report: return phaseLabel == "Move-out" ? "View move-out report" : "View move-in report"
        case .retry: return "Retry \(ProofSavedReceiptView.count(pendingCount, "photo"))"
        case .done: return "Done"
        }
    }

    func model(imageURL: URL?) -> ProofSavedReceiptModel {
        ProofSavedReceiptModel(
            roomName: roomName, phaseLabel: phaseLabel, photoCount: photoCount, pendingCount: pendingCount,
            issueCount: issueCount, savedAt: savedAt, imageURL: imageURL, primaryActionLabel: primaryActionLabel
        )
    }
}

/// The receipt, with the photo just saved (the rental's newest evidence).
struct SavedRoomReceiptScreen: View {
    let receipt: SavedRoomReceipt
    let onAction: (SavedRoomReceipt.Action) -> Void

    @Environment(PropertyStore.self) private var propertyStore
    @State private var imageURL: URL?

    var body: some View {
        ProofSavedReceiptView(
            model: receipt.model(imageURL: imageURL),
            onPrimary: { onAction(.primary) },
            onSecondary: { onAction(.viewEvidence) },
            onAddMorePhotos: receipt.next == .retry ? nil : { onAction(.addMore) }
        )
        .task {
            if let id = receipt.propertyId { imageURL = await propertyStore.previewImageURL(for: id) }
        }
    }
}
