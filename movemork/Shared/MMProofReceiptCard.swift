//
//  MMProofReceiptCard.swift
//  movemork
//
//  Shared proof receipt — photo, room, saved status, meta.
//

import SwiftUI

struct MMProofReceiptCard: View {
    let statusLabel: String
    let title: String
    let metaLine: String
    var thumbnailImageName: String? = "welcome-kitchen-main"
    var thumbnailURL: URL? = nil

    var body: some View {
        ProofReceiptStrip(
            model: ProofReceiptStripModel(
                statusBadge: statusLabel,
                statusTone: .neutral,
                cardTitle: title,
                cardMeta: metaLine
            ),
            layout: .horizontal,
            leading: {
                ProofPhotoPane(
                    size: .thumbnail,
                    imageName: thumbnailImageName,
                    imageURL: thumbnailURL
                )
            }
        )
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.52), lineWidth: 0.75)
        )
    }
}
