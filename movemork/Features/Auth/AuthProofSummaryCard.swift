//
//  AuthProofSummaryCard.swift
//  movemork
//
//  Prominent proof receipt — the thing the user is saving.
//

import SwiftUI

struct AuthProofSummaryCard: View {
    let mode: AuthContainerView.Mode

    private let receiptHeight: CGFloat = 98
    private let thumbSize: CGFloat = 64

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            thumbnail
                .frame(width: thumbSize, height: thumbSize)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                statusChip
                    .id("auth-summary-chip-\(mode == .signIn ? "in" : "up")")

                Text("Kitchen proof")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .id("auth-summary-title-\(mode == .signIn ? "in" : "up")")

                Text(metaLine)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.8))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .id("auth-summary-meta-\(mode == .signIn ? "in" : "up")")
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

    private var statusChip: some View {
        Text(statusLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.85))
            )
            .overlay(
                Capsule()
                    .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.55), lineWidth: 0.65)
            )
    }

    private var thumbnail: some View {
        ZStack {
            Image("welcome-kitchen-main")
                .resizable()
                .scaledToFill()

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.14))
        }
        .clipped()
    }

    private var statusLabel: String {
        mode == .signUp ? "Ready to save" : "Last saved"
    }

    private var metaLine: String {
        mode == .signUp
            ? "12 photos · 3 issues · Report ready"
            : "Move-in · 12 photos · Report ready"
    }
}
