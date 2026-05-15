//
//  WelcomeScreen.swift
//  movemork
//
//  MoveMark — Cinematic proof-over-apartment welcome.
//

import SwiftUI

struct WelcomeScreen: View {
    @State private var showAuth = false
    @State private var authInitialMode: AuthContainerView.Mode = .signUp

    @State private var atmosphereVisible = false
    @State private var metalAnimating = true
    @State private var depthActive = true
    @State private var depthReveal: CGFloat = 0
    @State private var imageVisible = false
    @State private var evidenceVisible = false
    @State private var depositVisible = false
    @State private var ringProgress: CGFloat = 0
    @State private var scanlineTrigger = 0
    @State private var copyVisible = false
    @State private var ctaVisible = false
    @State private var ctaGlintTrigger = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let contentPadding: CGFloat = 20

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let heroHeight = geo.size.height * 0.48

                ZStack(alignment: .top) {
                    MoveMarkTheme.Colors.appBackground
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            WelcomeProofHeroZone(
                                width: geo.size.width,
                                height: heroHeight,
                                metalAnimating: metalAnimating,
                                depthActive: depthActive,
                                depthReveal: depthReveal,
                                imageVisible: imageVisible,
                                evidenceVisible: evidenceVisible,
                                depositVisible: depositVisible,
                                ringProgress: ringProgress,
                                scanlineTrigger: scanlineTrigger
                            )
                            .opacity(atmosphereVisible ? 1 : 0)

                            Text("MoveMark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.92))
                                .padding(.horizontal, contentPadding)
                                .padding(.top, max(12, geo.safeAreaInsets.top + 6))
                                .opacity(imageVisible ? 1 : 0)
                        }

                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                headlineBlock
                                    .padding(.horizontal, contentPadding)
                                    .padding(.top, 20)

                                ctaBlock
                                    .padding(.horizontal, contentPadding)
                                    .padding(.top, 22)
                                    .padding(.bottom, max(20, geo.safeAreaInsets.bottom + 12))
                            }
                        }
                        .background(bottomFade)
                    }
                }
            }
            .onAppear {
                playEntrance()
                scheduleAtmosphereSettle()
            }
            .navigationDestination(isPresented: $showAuth) {
                AuthContainerView(initialMode: authInitialMode)
            }
        }
    }

    private var bottomFade: some View {
        LinearGradient(
            colors: [
                MoveMarkTheme.Colors.appBackground.opacity(0),
                MoveMarkTheme.Colors.appBackground.opacity(0.92),
                MoveMarkTheme.Colors.appBackground
            ],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.12)
        )
        .allowsHitTesting(false)
    }

    private func playEntrance() {
        if reduceMotion {
            atmosphereVisible = true
            metalAnimating = false
            depthActive = false
            depthReveal = 1
            imageVisible = true
            evidenceVisible = true
            depositVisible = true
            ringProgress = 0.82
            copyVisible = true
            ctaVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.5)) { atmosphereVisible = true }
        withAnimation(.easeOut(duration: 0.55).delay(0.08)) {
            depthReveal = 1
            imageVisible = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.16)) { evidenceVisible = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.24)) {
            depositVisible = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.24)) {
            ringProgress = 0.82
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            scanlineTrigger += 1
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.34)) { copyVisible = true }
        withAnimation(.easeOut(duration: 0.4).delay(0.42)) {
            ctaVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ctaGlintTrigger += 1
        }
    }

    private func scheduleAtmosphereSettle() {
        guard !reduceMotion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            metalAnimating = false
            depthActive = false
        }
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Get your deposit back.")
                .font(.system(size: 36, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Take photos now. Make a report later.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(copyVisible ? 1 : 0)
        .offset(y: copyVisible ? 0 : 6)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.34), value: copyVisible)
    }

    private var ctaBlock: some View {
        VStack(spacing: 12) {
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                MoveMarkTheme.Colors.primary.opacity(0.09),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 88
                        )
                    )
                    .frame(height: 50)
                    .offset(y: 6)
                    .opacity(ctaVisible ? 1 : 0)

                MMButton(
                    title: "Start proof",
                    action: {
                        MMHaptics.soft()
                        authInitialMode = .signUp
                        showAuth = true
                    },
                    showsTrailingArrow: true
                )
                .mmCTAGlint(trigger: ctaGlintTrigger)
            }

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text("Already have an account?")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                Button {
                    MMHaptics.soft()
                    authInitialMode = .signIn
                    showAuth = true
                } label: {
                    Text("Sign in")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.limeAccent)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
        }
        .opacity(ctaVisible ? 1 : 0)
        .offset(y: ctaVisible ? 0 : 6)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.42), value: ctaVisible)
    }
}
