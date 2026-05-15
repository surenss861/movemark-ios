//
//  WelcomeProtectionChip.swift
//  movemork
//
//  Single quiet supporting chip for Welcome.
//

import SwiftUI

struct WelcomeProtectionChip: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("Deposit protected")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(MoveMarkTheme.Colors.proofMint)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(MoveMarkTheme.Colors.cardRaised.opacity(0.95))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.15), radius: 8, y: 4)
    }
}
