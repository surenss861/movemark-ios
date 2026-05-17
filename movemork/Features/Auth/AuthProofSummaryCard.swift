//
//  AuthProofSummaryCard.swift
//  movemork
//
//  Compact proof receipt — continuation of Welcome hero.
//

import SwiftUI

struct AuthProofSummaryCard: View {
    let mode: AuthContainerView.Mode

    private let receiptHeight: CGFloat = 80

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.82))
                    .id("auth-summary-eyebrow-\(mode == .signIn ? "in" : "up")")

                Text("Kitchen proof")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .id("auth-summary-title-\(mode == .signIn ? "in" : "up")")

                Text(detailLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .id("auth-summary-detail-\(mode == .signIn ? "in" : "up")")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: receiptHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.72), lineWidth: 0.75)
        )
    }

    private var thumbnail: some View {
        ZStack {
            Image("welcome-kitchen-main")
                .resizable()
                .scaledToFill()

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.18))
        }
        .clipped()
    }

    private var eyebrow: String {
        mode == .signUp ? "Ready to save" : "Last saved"
    }

    private var detailLine: String {
        mode == .signUp
            ? "12 photos · 3 issues · Report ready"
            : "Move-in · 12 photos · Report ready"
    }
}
