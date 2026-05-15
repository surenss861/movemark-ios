//
//  MMDepositProtectionCard.swift
//  movemork
//
//  Deposit protection — emerald premium card.
//

import SwiftUI

struct MMDepositProtectionCard: View {
    let depositDisplay: String
    let proofScoreLabel: String
    let summaryLine: String
    var roomsLine: String? = nil
    var style: MMProofHeroCard.Style = .premium

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.limeAccent)
                Text("Deposit protection")
                    .font(MoveMarkTheme.Typography.caption)
                    .tracking(0.8)
                    .foregroundStyle(MoveMarkTheme.Colors.limeAccent.opacity(0.9))
                    .textCase(.uppercase)
                Spacer()
                MMPill(text: proofScoreLabel, tone: .success)
            }

            Text(depositDisplay)
                .font(MoveMarkTheme.Typography.cardValue)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(summaryLine)
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            if let roomsLine, !roomsLine.isEmpty {
                Text(roomsLine)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.proofMint)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [MoveMarkTheme.Colors.cardRaised, MoveMarkTheme.Colors.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MoveMarkTheme.Colors.limeAccent.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.2), radius: 16, y: 8)
    }
}
