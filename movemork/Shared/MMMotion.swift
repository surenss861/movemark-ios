//
//  MMMotion.swift
//  movemork
//
//  Motion tokens: deliberate, calm, no bounce. State changes clarify, not decorate.
//
//  Families: tabs = one-frame page swap + content-region entrance (MMTabContentTransition) · cards = soft rise · rows = press scale ·
//  sheets = bottom lift · proof saved = green pulse · errors = amber fade.
//

import SwiftUI

enum MMMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let fastFade = Animation.easeOut(duration: 0.18)
    static let cardReveal = Animation.easeOut(duration: 0.24)
    static let screenTransition = Animation.easeOut(duration: 0.26)
    static let expand = Animation.spring(response: 0.34, dampingFraction: 0.88)
    static let tabSwitch = Animation.easeOut(duration: 0.2)
    /// Root tabs: the classic dock's lime signal and active icon glide (tactile, no bounce). Scoped to the dock.
    static let tabIndicator = Animation.spring(response: 0.28, dampingFraction: 0.88)
    /// Root tabs: the pill dock transforms to the new tab (~240 ms, no visible overshoot). Slightly more
    /// expressive than the page content, which is the hierarchy: the dock moves, the screen just arrives.
    static let tabDockPill = Animation.spring(response: 0.24, dampingFraction: 0.88)
    // Root-tab page switch (MMTabContentTransition). The page itself swaps in one frame; these only shape the new
    // page's content region in variants B (directional) and C (dissolve).
    /// B: the content region travels this far (pt) along the direction of the tab change.
    static let tabContentShift: CGFloat = 8
    /// B: duration of that travel (s), ease-out.
    static let tabContentMoveDuration: TimeInterval = 0.22
    /// B: duration of the content resolving (s).
    static let tabContentFadeDuration: TimeInterval = 0.16
    /// C: duration of the in-place dissolve (s).
    static let tabContentDissolveDuration: TimeInterval = 0.14
    /// Reduce Motion (B and C): a short dissolve, no movement (s).
    static let tabContentReducedDuration: TimeInterval = 0.12
    /// B / C: how much of the content the sheet-coloured cover hides on the first frame (never a blank sheet).
    static let tabContentCoverStart: Double = 0.4
    /// A switch arriving within this window of the previous one lands instantly: rapid taps never stack
    /// entrances and never show a half-resolved page.
    static let tabContentInterruptWindow: Duration = .milliseconds(260)
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
