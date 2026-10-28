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
/// Alpha composites as 1-(1-a)(1-b), not a+b. Three layers:
/// - a vertical ramp that leaves the band under the status bar light enough to read the doorway, then
///   holds a firm dark floor from the brand lockup down through the headline, body and dock;
/// - a soft pool of shadow behind the copy column (centre-left), so the lit middle of the frame recedes
///   and the type sits *in* the photograph rather than on top of it;
/// - a leading-edge falloff so the open doorway and cabinetry on the right keep their light.
struct WelcomeReadabilityVeil: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: MMInk.hero.opacity(0.34), location: 0.00),
                    .init(color: MMInk.hero.opacity(0.14), location: 0.12),
                    .init(color: MMInk.hero.opacity(0.30), location: 0.22),
                    .init(color: MMInk.hero.opacity(0.44), location: 0.34),
                    .init(color: MMInk.hero.opacity(0.54), location: 0.52),
                    .init(color: MMInk.hero.opacity(0.70), location: 0.68),
                    .init(color: MMInk.hero.opacity(0.84), location: 0.84),
                    .init(color: MMInk.hero.opacity(0.92), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { geo in
                RadialGradient(
                    colors: [MMInk.hero.opacity(0.44), MMInk.hero.opacity(0.0)],
                    center: UnitPoint(x: 0.18, y: 0.4),
                    startRadius: 0,
                    endRadius: max(geo.size.width, geo.size.height) * 0.36
                )
            }

            LinearGradient(
                stops: [
                    .init(color: MMInk.hero.opacity(0.26), location: 0.0),
                    .init(color: MMInk.hero.opacity(0.0), location: 0.62)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
