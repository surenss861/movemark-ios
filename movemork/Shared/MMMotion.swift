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
    static let tabSwitch = Animation.easeOut(duration: 0.2)
    static let tabContentShift: CGFloat = 8
    /// Proof strength / walkthrough progress — ease only, no bounce.
    static let proofProgress = Animation.easeOut(duration: 0.42)
    static let proofToastIn = Animation.easeOut(duration: 0.28)
    static let proofToastOut = Animation.easeIn(duration: 0.2)
    /// Report card unlock — soft scale, no bounce.
    static let reportUnlock = Animation.easeOut(duration: 0.45)
}

extension View {
    /// Gentle lift when a report becomes ready (respects Reduce Motion).
    func mmReportUnlockPulse(active: Bool) -> some View {
        modifier(MMReportUnlockPulseModifier(active: active))
    }
}

private struct MMReportUnlockPulseModifier: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && !reduceMotion ? 1.02 : 1.0)
            .animation(reduceMotion ? nil : MMMotion.reportUnlock, value: active)
    }
}

extension View {
    /// Staggered list/card entrance: opacity + small vertical offset, calm ease-out.
    func mmStaggeredAppear(isVisible: Bool, index: Int, baseDelay: Double = 0) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(MMMotion.cardReveal.delay(baseDelay + Double(index) * 0.04), value: isVisible)
    }
}
