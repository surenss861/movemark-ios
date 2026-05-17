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

    private let receiptHeight: CGFloat = 98
    private let thumbSize: CGFloat = 64

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            thumbnail
                .frame(width: thumbSize, height: thumbSize)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.85))
                    )

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text(metaLine)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.8))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(height: receiptHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.52), lineWidth: 0.75)
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            if let thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        thumbnailPlaceholder
                    }
                }
            } else if let thumbnailImageName {
                Image(thumbnailImageName)
                    .resizable()
                    .scaledToFill()
            } else {
                thumbnailPlaceholder
            }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.14))
        }
        .clipped()
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            MoveMarkTheme.Colors.fieldFill
            Image(systemName: "photo")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
        }
    }
}
