//
//  WelcomeScreen.swift
//  movemork
//
//  MoveMark — “Before they blame you” welcome (fixed zones, evidence capture hero).
//

import SwiftUI

struct WelcomeScreen: View {
    @State private var showAuth = false
    @State private var authInitialMode: AuthContainerView.Mode = .signUp
    /// New ID each launch so dismissed auth always reopens in the requested mode with a clean form.
    @State private var authPresentationID = UUID()
    @State private var launchCTAPressed = false

    @State private var cardVisible = false
    @State private var tagsVisible = false
    @State private var copyVisible = false
    @State private var ctaVisible = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let contentPadding: CGFloat = 18
    /// Screen-edge inset for the bottom launch dock (38–40pt total).
    private let launchDockHorizontalInset: CGFloat = 38

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let layout = WelcomeZoneLayout(
                    screenHeight: geo.size.height,
                    safeTop: geo.safeAreaInsets.top,
                    safeBottom: geo.safeAreaInsets.bottom
                )
                let cardWidth = min(geo.size.width - contentPadding * 2, 450)
                let dockSideInset = max(0, launchDockHorizontalInset - contentPadding)

            ZStack {
                    // Frame 0 of the shipped master, so the handoff to video is invisible.
                    // Also the Reduce Motion presentation and the failure path if the asset
                    // is missing or AVFoundation cannot prepare it.
                    Image("WelcomeBackgroundPoster")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .accessibilityHidden(true)

                    if !reduceMotion {
                        WelcomeBackgroundVideo(isPlaying: shouldPlayWelcomeVideo)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    welcomeVideoTreatment
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    welcomeContent(
                        layout: layout,
                        cardWidth: cardWidth,
                        dockSideInset: dockSideInset,
                        safeBottom: geo.safeAreaInsets.bottom
                    )
                    .opacity(showAuth ? 0.32 : 1)
                    .scaleEffect(showAuth ? 0.96 : 1, anchor: .center)
                    .allowsHitTesting(!showAuth)
                    .animation(welcomeBackdropAnimation, value: showAuth)

                    if showAuth {
                        Color.black.opacity(0.38)
                    .ignoresSafeArea()
                            .transition(reduceMotion ? .opacity : .opacity.animation(.easeOut(duration: 0.28)))

                        AuthContainerView(initialMode: authInitialMode) {
                            dismissAuth()
                        }
                        .id(authPresentationID)
                        .transition(authSurfaceTransition)
                        .zIndex(10)
                    }
                }
            }
            .onAppear { playEntrance() }
            .onAppear {
                MoveMarkAnalytics.track(.onboardingStarted)
            }
        }
    }

    // MARK: - Welcome content

    private func welcomeContent(
        layout: WelcomeZoneLayout,
        cardWidth: CGFloat,
        dockSideInset: CGFloat,
        safeBottom: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            brandIdentityRow
                .padding(.bottom, layout.brandToHeroGap)

            WelcomeDepositCaseFile(
                maxWidth: cardWidth,
                cardVisible: cardVisible,
                tagsVisible: tagsVisible
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            primaryCopyBlock
                .padding(.top, layout.heroToCopyGap)

            Spacer(minLength: 8)

            bottomLaunchDock
                .padding(.horizontal, dockSideInset)
        }
        .padding(.horizontal, contentPadding)
        .padding(.top, layout.topPadding)
        .padding(.bottom, layout.bottomDockPadding(safeBottom: safeBottom))
    }

    private var welcomeBackdropAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9)
    }

    private var authSurfaceTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }

    private func launchAuth(mode: AuthContainerView.Mode) {
        MMHaptics.soft()
        authInitialMode = mode
        authPresentationID = UUID()

        if reduceMotion {
            showAuth = true
            return
        }

        withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
            launchCTAPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                showAuth = true
                launchCTAPressed = false
            }
        }
    }

    private func dismissAuth() {
        if reduceMotion {
            showAuth = false
            return
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            showAuth = false
        }
    }

    // MARK: - Background treatment

    /// Nothing decodes unless the video is actually the thing being looked at.
    private var shouldPlayWelcomeVideo: Bool {
        !reduceMotion && !showAuth && scenePhase == .active
    }

    /// Deliberately light. The master is already graded dark and its UI zones were measured
    /// safe (headline ~0.50 luma, CTA ~0.12), so this sets colour character rather than
    /// re-grading the footage. Alpha composites as 1-(1-a)(1-b), not a+b: 0.12 over 0.20
    /// is ~0.30 at the bottom edge, which is as far as an already-dark CTA region should go.
    private var welcomeVideoTreatment: some View {
        ZStack {
            MoveMarkTheme.Colors.forestGreen
                .opacity(0.12)

            LinearGradient(
                stops: [
                    .init(color: MoveMarkTheme.Colors.appBackground.opacity(0.16), location: 0.00),
                    .init(color: MoveMarkTheme.Colors.appBackground.opacity(0.06), location: 0.48),
                    .init(color: MoveMarkTheme.Colors.appBackground.opacity(0.08), location: 0.70),
                    .init(color: MoveMarkTheme.Colors.appBackground.opacity(0.20), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Brand

    private var brandIdentityRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("MoveMarkLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 35, height: 35)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("MoveMark")
                .font(MoveMarkTheme.Typography.subtitleLarge)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Spacer(minLength: 0)
        }
        .opacity(cardVisible ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: cardVisible)
    }

    // MARK: - Copy (hero explains; dock launches)

    private var primaryCopyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(MoveMarkGrowthCopy.welcomeHeadline)
                .font(MoveMarkTheme.Typography.cardValue)
                .tracking(-0.7)
                .lineSpacing(2)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.92)
                .fixedSize(horizontal: false, vertical: true)

            Text(MoveMarkGrowthCopy.welcomeBody)
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.98))
                // Body only — the headline keeps the full width so it stays on one line on large
                // devices. Aspect-fill puts the lit wall and curtain on the right of wide screens,
                // and this is the copy that runs into it; wrapping earlier keeps it over the dark
                // centre-left rather than asking a scrim to cover ever more of the frame.
                .frame(maxWidth: 330, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Anchored to the copy, not to a region of the video: aspect-fill puts different
            // footage behind this text on every device, so a fixed video-space allowance cannot
            // protect it. `maxWidth` above pulls the copy off the lit curtain, but the lit wall
            // still sits behind the centre-left on wide screens — measured 0.47 background
            // luminance without this, 0.33 with it. Falls to clear on the right so it reads as
            // shading rather than a panel.
            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.appBackground.opacity(0.34),
                    MoveMarkTheme.Colors.appBackground.opacity(0.18),
                    .clear
                ],
                center: UnitPoint(x: 0.32, y: 0.50),
                startRadius: 10,
                endRadius: 330
            )
            .blur(radius: 14)
            .padding(.horizontal, -24)
            .padding(.vertical, -18)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .opacity(copyVisible ? 1 : 0)
        .offset(y: copyVisible ? 0 : 8)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.44).delay(0.22), value: copyVisible)
    }

    // MARK: - Bottom launch dock

    private var bottomLaunchDock: some View {
        VStack(spacing: 0) {
            MMButton(
                title: MoveMarkGrowthCopy.welcomeCTA,
                action: { launchAuth(mode: .signUp) },
                showsTrailingArrow: true
            )
            .scaleEffect(launchCTAPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: launchCTAPressed)
            .accessibilityIdentifier("welcome.primaryCTA")

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text("Already have an account?")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
                Button {
                    launchAuth(mode: .signIn)
                } label: {
                    Text("Sign in")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.95))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("welcome.signIn")
                Spacer(minLength: 0)
            }
            .padding(.top, 22)
        }
        .opacity(ctaVisible ? 1 : 0)
        .offset(y: ctaVisible ? 0 : 10)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.42).delay(0.32), value: ctaVisible)
    }

    private func playEntrance() {
        if reduceMotion {
            cardVisible = true
            tagsVisible = true
            copyVisible = true
            ctaVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.48)) {
            cardVisible = true
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82).delay(0.14)) {
            tagsVisible = true
        }
        withAnimation(.easeOut(duration: 0.44).delay(0.22)) {
            copyVisible = true
        }
        withAnimation(.easeOut(duration: 0.42).delay(0.32)) {
            ctaVisible = true
        }
    }
}

// MARK: - Zone layout

private struct WelcomeZoneLayout {
    let topPadding: CGFloat
    let brandToHeroGap: CGFloat
    let heroToCopyGap: CGFloat

    init(screenHeight: CGFloat, safeTop: CGFloat, safeBottom: CGFloat) {
        topPadding = max(4, safeTop - 71)
        brandToHeroGap = 14
        heroToCopyGap = 22
    }

    func bottomDockPadding(safeBottom: CGFloat) -> CGFloat {
        max(36, safeBottom + 18)
    }
}
