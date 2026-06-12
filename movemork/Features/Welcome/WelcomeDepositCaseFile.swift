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

    var body: some View {
        WelcomeProofPreviewCard(
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
