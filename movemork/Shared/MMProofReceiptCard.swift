//
//  MMProofReceiptCard.swift
//  movemork
//
//  Strongest proof moment — artifact card with saved photo.
//

import SwiftUI

struct MMProofReceiptCard: View {
    let statusLabel: String
    let title: String
    let metaLine: String
    var thumbnailImageName: String? = "welcome-proof-hero"
    var thumbnailURL: URL? = nil
    var photoCount: Int = 1
    var issueCount: Int = 0
    var phaseLabel: String = "Move-in"

    var body: some View {
        ProofArtifactCard(
            model: ProofArtifactModel(
                phaseEyebrow: "Room Proof",
                phaseLabel: phaseLabel,
                roomName: title,
                photoCount: photoCount,
                issueCount: issueCount,
                verifiedLabel: metaLine,
                savedLabel: "Saved to vault",
                statusLabel: statusLabel,
                statusTone: .success
            ),
            photoHeight: 196,
            cornerRadius: 20,
            imageName: thumbnailImageName,
            imageURL: thumbnailURL,
            tagsVisible: false
        )
    }
}
