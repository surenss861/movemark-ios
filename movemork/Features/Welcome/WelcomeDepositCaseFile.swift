//
//  WelcomeDepositCaseFile.swift
//  movemork
//

import SwiftUI

struct WelcomeDepositCaseFile: View {
    let maxWidth: CGFloat
    var cardVisible: Bool = true
    var tagsVisible: Bool = false
    /// Passed straight through to the artifact's density. Decided by available vertical space
    /// in `WelcomeZoneLayout`, so this layer never has to know about devices either.
    var compactHeight: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WelcomeClaimProofStack(
            proofVisible: tagsVisible,
            compactHeight: compactHeight
        )
        .frame(maxWidth: min(maxWidth, 390))
        .padding(.top, 8)
        .opacity(cardVisible ? 1 : 0)
        .offset(y: cardVisible ? 0 : 14)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.48), value: cardVisible)
    }
}

struct WelcomeEvidenceDeskRuledPaper: View {
    var body: some View { EmptyView() }
}
