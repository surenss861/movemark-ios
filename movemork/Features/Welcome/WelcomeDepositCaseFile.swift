//
//  WelcomeDepositCaseFile.swift
//  movemork
//

import SwiftUI

struct WelcomeDepositCaseFile: View {
    let maxWidth: CGFloat
    var cardVisible: Bool = true
    var tagsVisible: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var welcomeArtifact: ProofArtifactModel {
        ProofArtifactModel(
            phaseEyebrow: "Room Proof",
            phaseLabel: "Move-in",
            roomName: "Kitchen",
            photoCount: 12,
            issueCount: 3,
            verifiedLabel: "Verified Apr 14 · 5:42 PM",
            savedLabel: "Saved to vault",
            statusLabel: "Ready",
            statusTone: .success,
            issueTags: ["Already there", "Chipped paint"]
        )
    }

    var body: some View {
        ProofArtifactCard(
            model: welcomeArtifact,
            photoHeight: 180,
            cornerRadius: 20,
            imageName: "welcome-kitchen-main",
            showReportPeek: true,
            tagsVisible: tagsVisible
        )
        .frame(maxWidth: maxWidth)
        .padding(.top, 8)
        .opacity(cardVisible ? 1 : 0)
        .offset(y: cardVisible ? 0 : 14)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.48), value: cardVisible)
    }
}

struct WelcomeEvidenceDeskRuledPaper: View {
    var body: some View { EmptyView() }
}
