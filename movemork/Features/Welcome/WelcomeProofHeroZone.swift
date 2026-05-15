//
//  WelcomeProofHeroZone.swift
//  movemork
//
//  Cinematic apartment hero — Metal, SceneKit depth, SwiftUI proof layers.
//

import SwiftUI

struct WelcomeProofHeroZone: View {
    let width: CGFloat
    let height: CGFloat
    var metalAnimating: Bool = true
    var depthActive: Bool = true
    var depthReveal: CGFloat = 1
    var imageVisible: Bool = true
    var evidenceVisible: Bool = true
    var depositVisible: Bool = true
    var ringProgress: CGFloat = 0
    var scanlineTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let contentPadding: CGFloat = 20

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WelcomeEmeraldMetalView(isAnimating: metalAnimating && !reduceMotion)
                .frame(width: width, height: height)
                .opacity(imageVisible ? 1 : 0)

            if !reduceMotion {
                WelcomeHeroDepthView(isActive: depthActive, revealProgress: depthReveal)
                    .frame(width: width, height: height)
                    .opacity(imageVisible ? 0.5 : 0)
            }

            heroImage
            imageOverlays
            heroToContentBlend
            floatingCards
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var heroImage: some View {
        Image("WelcomeProofHero")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .opacity(imageVisible ? (reduceMotion ? 1 : 0.94) : 0)
            .offset(y: imageVisible ? 0 : 6)
    }

    private var imageOverlays: some View {
        ZStack {
            LinearGradient(
                colors: [
                    MoveMarkTheme.Colors.appBackground.opacity(0.42),
                    .clear,
                    MoveMarkTheme.Colors.appBackground.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.55)
            )

            LinearGradient(
                colors: [
                    MoveMarkTheme.Colors.primary.opacity(0.1),
                    .clear,
                    MoveMarkTheme.Colors.appBackground.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }

    /// Soft fade into lower content — no hard photo edge.
    private var heroToContentBlend: some View {
        LinearGradient(
            colors: [.clear, MoveMarkTheme.Colors.appBackground.opacity(0.35), MoveMarkTheme.Colors.appBackground],
            startPoint: UnitPoint(x: 0.5, y: 0.55),
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    private var floatingCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            evidenceCard
            depositPayoffBadge
        }
        .padding(.horizontal, contentPadding)
        .padding(.bottom, 20)
        .mmScanline(trigger: scanlineTrigger, intensity: 0.12)
    }

    private var evidenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Move-in proof")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Text("Kitchen")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text("12 photos saved")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            HStack(spacing: 6) {
                thumb("welcome-kitchen-main")
                thumb("welcome-kitchen-2")
                thumb("welcome-kitchen-3")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mmProofCardSurface(.evidence, cornerRadius: 20)
        .opacity(evidenceVisible ? 1 : 0)
        .offset(y: evidenceVisible ? 0 : 12)
    }

    private var depositPayoffBadge: some View {
        HStack(spacing: 12) {
            ZStack {
                MMProofRingOverlay(progress: ringProgress)
                    .frame(width: 36, height: 36)
                Text("82")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("$2,400")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                Text("Deposit protected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }

            Spacer(minLength: 0)

            Text("Report ready")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(MoveMarkTheme.Colors.primary.opacity(0.28)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .mmProofCardSurface(.depositPayoff, cornerRadius: 16)
        .opacity(depositVisible ? 1 : 0)
        .offset(y: depositVisible ? 0 : 8)
    }

    private func thumb(_ name: String) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
            )
    }
}
