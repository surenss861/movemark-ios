//
//  MMDepositProtectionCard.swift
//  movemork
//
//  Deposit protection — quiet supporting card (not a finance hero).
//

import SwiftUI

struct MMDepositProtectionCard: View {
    let depositDisplay: String
    let proofScoreLabel: String
    let summaryLine: String
    var roomsLine: String? = nil
    var style: MMProofHeroCard.Style = .premium

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.85))
                Text("Deposit protection")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                Spacer()
                MMPill(text: proofScoreLabel, tone: .success)
            }

            Text(depositDisplay)
                .font(MoveMarkTheme.Typography.cardTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(summaryLine)
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            if let roomsLine, !roomsLine.isEmpty {
                Text(roomsLine)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.7), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
