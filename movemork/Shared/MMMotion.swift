//
//  MMMotion.swift
//  movemork
//
//  Motion tokens: deliberate, calm, no bounce. State changes clarify, not decorate.
//

import SwiftUI

enum MMMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let fastFade = Animation.easeOut(duration: 0.18)
    static let cardReveal = Animation.easeOut(duration: 0.24)
    static let screenTransition = Animation.easeOut(duration: 0.26)
    static let expand = Animation.spring(response: 0.34, dampingFraction: 0.88)
    static let tabSwitch = Animation.easeOut(duration: 0.22)
    /// Proof strength / walkthrough progress — ease only, no bounce.
    static let proofProgress = Animation.easeOut(duration: 0.42)
}

extension View {
    /// Staggered list/card entrance: opacity + small vertical offset, calm ease-out.
    func mmStaggeredAppear(isVisible: Bool, index: Int, baseDelay: Double = 0) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(MMMotion.cardReveal.delay(baseDelay + Double(index) * 0.04), value: isVisible)
    }
}
