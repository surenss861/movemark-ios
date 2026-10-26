//
//  WelcomeGrade.swift
//  movemork
//
//  Welcome-only — neutral grade and readability veil for the background footage.
//

import SwiftUI

/// Pulls the footage toward neutral. The master carries saturated teal cabinetry in the lit doorway;
/// left as shot it reads as the brand colour behind the headline. A grey layer in `.saturation` blend
/// takes most of the chroma out without touching luminance, so the frame stays as dark and as deep as
/// it was — only calmer. No hue is added.
struct WelcomeNeutralGrade: View {
    var body: some View {
        Color(white: 0.5)
            .opacity(0.85)
            .blendMode(.saturation)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Luminance shaping only, in the system's header ink (#161817): buys text contrast, never changes hue.
///
/// Alpha composites as 1-(1-a)(1-b), not a+b. The foot is the heaviest stop because the primary action
/// and the copy sit there and the frame's own light falls off toward the bottom edge.
struct WelcomeReadabilityVeil: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: MMInk.hero.opacity(0.30), location: 0.00),
                    .init(color: MMInk.hero.opacity(0.10), location: 0.25),
                    .init(color: MMInk.hero.opacity(0.32), location: 0.45),
                    .init(color: MMInk.hero.opacity(0.55), location: 0.65),
                    .init(color: MMInk.hero.opacity(0.76), location: 0.82),
                    .init(color: MMInk.hero.opacity(0.88), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
