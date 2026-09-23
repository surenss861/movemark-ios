//
//  WelcomeEmeraldGrade.swift
//  movemork
//
//  Welcome-only — brand grade for the background video.
//

import SwiftUI

/// Grades the apartment footage into MoveMark's world instead of painting green over it.
///
/// A flat `forestGreen.opacity(0.12)` fill lifts the blacks and flattens the whole frame — the
/// footage ends up sitting *under* a green sheet rather than belonging to the brand. Soft light
/// leaves the darks alone and pulls the midtones toward emerald, which is where the apartment's
/// walls and cabinetry actually live, so the cast lands on the surfaces that should carry it.
///
/// The radial sits off-centre-right over the lit kitchen doorway, the brightest region of the
/// master, so the grade is strongest exactly where the footage would otherwise go neutral.
struct WelcomeEmeraldGrade: View {
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.20, blue: 0.11)
                .opacity(0.09)
                .blendMode(.softLight)

            RadialGradient(
                colors: [
                    Color(red: 0.04, green: 0.24, blue: 0.14).opacity(0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.65, y: 0.50),
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        // Soft light needs its own compositing group, otherwise it blends against whatever the
        // ZStack has already drawn rather than against the video alone.
        .compositingGroup()
    }
}

/// Luminance shaping, kept separate from the grade so the two can be reasoned about apart:
/// this one only buys text contrast and never changes hue.
///
/// The master is already graded dark and its UI zones were measured safe (headline ~0.50 luma,
/// CTA ~0.12). Alpha composites as 1-(1-a)(1-b), not a+b. The foot is the heaviest stop because
/// the launch control sits there and the frame's own light falls off toward the bottom edge.
struct WelcomeReadabilityVeil: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: MoveMarkTheme.Colors.appBackground.opacity(0.16), location: 0.00),
                    .init(color: MoveMarkTheme.Colors.appBackground.opacity(0.06), location: 0.48),
                    .init(color: MoveMarkTheme.Colors.appBackground.opacity(0.10), location: 0.72),
                    .init(color: MoveMarkTheme.Colors.appBackground.opacity(0.30), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Edge vignette. Pulls the corners down so the frame reads as a scene being looked
            // into rather than a rectangle of footage butted against the bezel.
            RadialGradient(
                colors: [
                    .clear,
                    MoveMarkTheme.Colors.appBackground.opacity(0.26)
                ],
                center: .center,
                startRadius: 260,
                endRadius: 760
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
