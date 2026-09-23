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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    /// Card and copy sit 20pt off each edge, so the receipt is exactly screen width - 40.
    private let contentPadding: CGFloat = 20
    /// Screen-edge inset for the bottom launch dock (38–40pt total).
    private let launchDockHorizontalInset: CGFloat = 30

    /// Accessibility Dynamic Type only. Keep the fixed poster composition through `.xxxLarge`;
    /// at AX sizes the same content grows and scrolls so CTA + Sign in stay reachable.
    private var usesAccessibilityScrollLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let layout = WelcomeZoneLayout(
                    screenHeight: geo.size.height,
                    safeTop: geo.safeAreaInsets.top,
                    safeBottom: geo.safeAreaInsets.bottom
                )
                let cardWidth = min(geo.size.width - contentPadding * 2, 430)
                let dockSideInset = max(0, launchDockHorizontalInset - contentPadding)

            ZStack {
                    // Frame 0 of the shipped master, so the handoff to video is invisible.
                    // Also the Reduce Motion presentation and the failure path if the asset
                    // is missing or AVFoundation cannot prepare it.
                    //
                    // Painted through an overlay rather than placed directly in the ZStack.
                    // `scaledToFill` reports the *filled* size, not the proposed one: the poster
                    // is 9:16, so on any screen taller than that it reports more width than it
                    // was offered — ~538pt against a 440pt proposal on a 17 Pro Max — and a
                    // ZStack sizes itself to its largest child. That widened the whole content
                    // stack, and since the GeometryReader pins its content top-leading, every
                    // point of the excess fell on the right: the launch dock's emerald chip ran
                    // off the screen edge while the fixed-width receipt above it looked fine.
                    // An overlay is sized by its host and never resizes it, so the fill is
                    // painted and clipped without reaching layout at all. The SE was immune
                    // only because 375x667 is exactly 9:16.
                    Color.clear
                        .overlay {
                            Image("WelcomeBackgroundPoster")
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                        .ignoresSafeArea()
                        .accessibilityHidden(true)

                    if !reduceMotion {
                        WelcomeBackgroundVideo(isPlaying: shouldPlayWelcomeVideo)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    // video -> emerald grade -> readability veil -> proof artifact -> copy -> CTA
                    WelcomeEmeraldGrade()
                    WelcomeReadabilityVeil()

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

    @ViewBuilder
    private func welcomeContent(
        layout: WelcomeZoneLayout,
        cardWidth: CGFloat,
        dockSideInset: CGFloat,
        safeBottom: CGFloat
    ) -> some View {
        // Poster/background stays fixed. Only the interactive layer scrolls at AX sizes —
        // and CTA + Sign in travel with that layer (no bottom dock) so they cannot collide
        // with grown copy the way a fixed dock would.
        if usesAccessibilityScrollLayout {
            ScrollView {
                welcomeInteractiveStack(
                    layout: layout,
                    cardWidth: cardWidth,
                    dockSideInset: dockSideInset,
                    pinsDockToBottom: false
                )
                .padding(.bottom, layout.bottomDockPadding(safeBottom: safeBottom))
            }
            .scrollIndicators(.hidden)
        } else {
            welcomeInteractiveStack(
                layout: layout,
                cardWidth: cardWidth,
                dockSideInset: dockSideInset,
                pinsDockToBottom: true
            )
            .padding(.bottom, layout.bottomDockPadding(safeBottom: safeBottom))
        }
    }

    private func welcomeInteractiveStack(
        layout: WelcomeZoneLayout,
        cardWidth: CGFloat,
        dockSideInset: CGFloat,
        pinsDockToBottom: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            brandIdentityRow
                .padding(.bottom, layout.brandToHeroGap)

            WelcomeDepositCaseFile(
                maxWidth: cardWidth,
                cardVisible: cardVisible,
                tagsVisible: tagsVisible,
                compactHeight: layout.isCompactHeight
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            primaryCopyBlock
                .padding(.top, layout.heroToCopyGap)

            if pinsDockToBottom {
                Spacer(minLength: 8)
            } else {
                Color.clear.frame(height: layout.heroToCopyGap)
            }

            bottomLaunchDock
                .padding(.horizontal, dockSideInset)
        }
        .padding(.horizontal, contentPadding)
        .padding(.top, layout.topPadding)
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

    // MARK: - Brand

    /// Wordmark only. The app icon already carries the mark on the Home Screen, and a badge
    /// beside the word here made the corner read as a logo lockup on a marketing page rather
    /// than as the quiet anchor this screen needs.
    private var brandIdentityRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("MoveMark")
                .font(MoveMarkTheme.Typography.wordmark)
                .tracking(-0.6)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.92))

            Spacer(minLength: 0)
        }
        .opacity(cardVisible ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: cardVisible)
    }

    // MARK: - Copy (hero explains; dock launches)

    private var primaryCopyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Two Text views rather than one wrapped string: SwiftUI has no line-height
            // multiplier, and a -4 VStack spacing is the only way to reach the ~0.96 leading
            // this size wants. It also makes the break editorial rather than a function of
            // device width — the headline is never one line, on any screen.
            VStack(alignment: .leading, spacing: -4) {
                Text(MoveMarkGrowthCopy.welcomeHeadlineLead)
                Text(MoveMarkGrowthCopy.welcomeHeadlineTail)
            }
            .font(MoveMarkTheme.Typography.welcomeHeadline)
            .tracking(-1.0)
            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            // Fixed composition: one editorial line per Text through xxxLarge.
            // Accessibility sizes: let the lines wrap and grow — scroll carries the overflow.
            .modifier(WelcomeHeadlineDynamicTypeFit(allowsWrapping: usesAccessibilityScrollLayout))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(MoveMarkGrowthCopy.welcomeHeadline)

            Text(MoveMarkGrowthCopy.welcomeBody)
                .font(MoveMarkTheme.Typography.welcomeBody)
                .foregroundStyle(MoveMarkTheme.Colors.textBodyNeutral.opacity(0.72))
                // Contrast the scrim cannot buy. The plate under this copy is bimodal on wide
                // screens — a lit door edge around 70-120pt and the lit wall from 250pt out, both
                // reaching 0.44 luma — so flattening the worst decile with the radial would take
                // an opacity that reads as a panel. These raise contrast at the character edge,
                // where it is actually judged, and cost the surrounding frame nothing. Shadow
                // colour is appBackground, so on an already-dark plate they render as nothing.
                .shadow(color: MoveMarkTheme.Colors.appBackground.opacity(0.85), radius: 3, x: 0, y: 1)
                .shadow(color: MoveMarkTheme.Colors.appBackground.opacity(0.55), radius: 10, x: 0, y: 2)
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
            // still sits behind the centre-left on wide screens — 0.42 background luma there
            // untreated, 0.29 with this. Falls to clear on the right so it reads as shading
            // rather than a panel; measured across the full 8s loop it also holds the plate
            // steady while the untreated footage beside it swings 0.35-0.39.
            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.appBackground.opacity(0.42),
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
            WelcomeLaunchControl(
                title: MoveMarkGrowthCopy.welcomeCTA,
                action: { launchAuth(mode: .signUp) }
            )
            .scaleEffect(launchCTAPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: launchCTAPressed)
            .accessibilityIdentifier("welcome.primaryCTA")

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text("Already have an account?")
                    .font(MoveMarkTheme.Typography.welcomeSupporting)
                    .foregroundStyle(MoveMarkTheme.Colors.textBodyNeutral.opacity(0.58))
                Button {
                    launchAuth(mode: .signIn)
                } label: {
                    Text("Sign in")
                        .font(MoveMarkTheme.Typography.welcomeSupportingEmphasis)
                        // Same emerald as the action chip, not `primary`. Emerald is a 44pt
                        // accent now, so a #21B866 link under it would be the brightest green
                        // on the screen — a secondary action out-shouting the primary one.
                        .foregroundStyle(MoveMarkTheme.Colors.ctaActionEmerald)
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
    /// Drives the proof artifact's density. Only the card responds to this — the zone gaps are
    /// identical on every device, so the screen keeps one spacing rhythm.
    let isCompactHeight: Bool

    init(screenHeight: CGFloat, safeTop: CGFloat, safeBottom: CGFloat) {
        topPadding = max(4, safeTop - 71)
        brandToHeroGap = 14
        heroToCopyGap = 22
        // Available vertical space, not a device check: an SE is short because of what it
        // leaves the layout, and a model list would be wrong again on the next phone. This is
        // the safe-area-excluded height, so the measured split is SE 647 and 13 mini 728 on the
        // compact side, iPhone 16 759 and 17 Pro Max 860 on the regular side.
        isCompactHeight = screenHeight < 750
    }

    func bottomDockPadding(safeBottom: CGFloat) -> CGFloat {
        max(36, safeBottom + 18)
    }
}

/// Keeps the default/compact headline fit frozen; only AX sizes unwrap and grow.
private struct WelcomeHeadlineDynamicTypeFit: ViewModifier {
    let allowsWrapping: Bool

    func body(content: Content) -> some View {
        if allowsWrapping {
            content
        } else {
            content
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
    }
}
