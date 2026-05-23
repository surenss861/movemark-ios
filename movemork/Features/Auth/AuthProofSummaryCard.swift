//
//  AuthProofSummaryCard.swift
//  movemork
//
//  Prominent proof receipt — the thing the user is saving.
//

import SwiftUI

struct AuthProofSummaryCard: View {
    let mode: AuthContainerView.Mode

    var body: some View {
        MMProofReceiptCard(
            statusLabel: statusLabel,
            title: "Kitchen proof",
            metaLine: metaLine,
            thumbnailImageName: "welcome-kitchen-main"
        )
        .id("auth-summary-\(mode == .signIn ? "in" : "up")")
    }

    private var statusLabel: String {
        mode == .signIn ? "Sign in to save proof" : "Create account to save proof"
    }

    private var metaLine: String {
        mode == .signIn ? "Your move-in photos stay in your vault." : "Start with one room — add more anytime."
    }
}
