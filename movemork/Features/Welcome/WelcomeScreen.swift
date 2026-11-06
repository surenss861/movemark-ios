//
//  WelcomeScreen.swift
//  movemork
//
//  MoveMark — Welcome: brand → outcome (headline + body) → trust (a compact Proof Slip, the record the
//  vault will hold) → action (lime Start move-in proof, a quiet way back into an existing vault).
//

import SwiftUI

struct WelcomeScreen: View {
    @State private var showAuth = false
    @State private var authInitialMode: AuthContainerView.Mode = .signUp
    /// New ID each launch so dismissed auth always reopens in the requested mode with a clean form.
    @State private var authPresentationID = UUID()

    /// One subtle fade for the whole page, once. Nothing moves in.
    @State private var entranceVisible = false
    /// False only in snapshot tests (see `init(previewSettled:)`); production always layers the video.
    private var showsVideo = true
    /// Snapshot tests only: render the Reduce Motion presentation without the system setting.
    private var forcesReduceMotion = false

    /// 0 → 1 once, shortly after the page fades in; 1 immediately under Reduce Motion.
    @State private var heroReveal: CGFloat = 0
    /// The hero's frames, where the grade and veil ease so the live footage reads clearer.
    @State private var heroCutouts: [CGRect] = []
    private static let space = "welcome"

    // Social sign-in (Debug + probe only until the security gates pass; see SocialSignIn.swift).
    private var socialOverride: Bool? = nil
    @State private var socialBusy: SocialProvider?
    @State private var socialError: String?
    @State private var probeResult: SocialProbeResult?
    private var showsSocial: Bool { socialOverride ?? SocialSignInConfig.isEnabled }

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionManager.self) private var sessionManager: SessionManager?

    private var reduceMotion: Bool { systemReduceMotion || forcesReduceMotion }

    /// Copy and slip sit 20pt off each edge.
    private let contentPadding: CGFloat = 20
    /// Screen-edge inset for the bottom launch dock (30pt total).
    private let launchDockHorizontalInset: CGFloat = 30
    /// The Welcome lockup is a step up from the 17pt header wordmark used everywhere else.
    private let wordmarkSize: CGFloat = 21

    /// Accessibility Dynamic Type only. Keep the fixed poster composition through `.xxxLarge`;
    /// at AX sizes the same content grows and scrolls so CTA + Sign in stay reachable.
    private var usesAccessibilityScrollLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    // No NavigationStack: nothing is ever pushed from Welcome, and a stack only reserved bar height
    // (visibly so in the window-less snapshot host, which ignored the hidden toolbar).
    var body: some View {
        GeometryReader { geo in
            let layout = WelcomeZoneLayout(
                screenHeight: geo.size.height,
                safeTop: geo.safeAreaInsets.top,
                safeBottom: geo.safeAreaInsets.bottom
            )
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
                // stack and pushed the launch dock off the right edge. An overlay is sized by
                // its host and never resizes it, so the fill is painted and clipped without
                // reaching layout at all.
                Color.clear
                    .overlay {
                        Image("WelcomeBackgroundPoster")
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                if !reduceMotion && showsVideo {
                    WelcomeBackgroundVideo(isPlaying: shouldPlayWelcomeVideo)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                // video -> neutral grade -> readability veil -> brand / copy / hero / actions. The hero's frames are
                // reported in this ZStack's (safe-area) space; the grade and veil are full-bleed, hence the shift.
                let cutouts = heroCutouts.map { $0.offsetBy(dx: geo.safeAreaInsets.leading, dy: geo.safeAreaInsets.top) }
                WelcomeNeutralGrade(cutouts: cutouts, cutoutStrength: 0.75)
                WelcomeReadabilityVeil(cutouts: cutouts, cutoutStrength: 0.7)

                welcomeContent(layout: layout, dockSideInset: dockSideInset, safeBottom: geo.safeAreaInsets.bottom)
                    .opacity(entranceVisible ? 1 : 0)
                    .opacity(showAuth ? 0.32 : 1)
                    .scaleEffect(showAuth && !reduceMotion ? 0.96 : 1, anchor: .center)
                    .allowsHitTesting(!showAuth)
                    .accessibilityHidden(showAuth)
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
            .coordinateSpace(name: Self.space)
            .onPreferenceChange(WelcomeCutoutKey.self) { heroCutouts = $0 }
        }
        .alert("Probe sign-in", isPresented: Binding(get: { probeResult != nil }, set: { if !$0 { probeResult = nil } })) {
            Button("OK", role: .cancel) { probeResult = nil }
        } message: {
            if let probeResult {
                Text("\(probeResult.provider.buttonTitle)\nNeon user: \(probeResult.userId.uuidString.lowercased())\nEmail: \(probeResult.email)\nSigned out of the probe.")
            }
        }
        .onAppear {
            playEntrance()
            MoveMarkAnalytics.track(.onboardingStarted)
        }
        // A finished password reset continues to sign in; an expired reset link to asking for a new one.
        .onReceive(NotificationCenter.default.publisher(for: .moveMarkOpenAuth)) { note in
            if let mode = note.object as? AuthContainerView.Mode { launchAuth(mode: mode) }
        }
    }

    // MARK: - Welcome content

    @ViewBuilder
    private func welcomeContent(layout: WelcomeZoneLayout, dockSideInset: CGFloat, safeBottom: CGFloat) -> some View {
        // Poster/background stays fixed. Only the interactive layer scrolls at AX sizes —
        // and CTA + Sign in travel with that layer (no bottom dock) so they cannot collide
        // with grown copy the way a fixed dock would.
        if usesAccessibilityScrollLayout {
            ScrollView {
                welcomeInteractiveStack(layout: layout, dockSideInset: dockSideInset, pinsDockToBottom: false)
                    .padding(.bottom, layout.bottomDockPadding(safeBottom: safeBottom))
            }
            .scrollIndicators(.hidden)
        } else {
            welcomeInteractiveStack(layout: layout, dockSideInset: dockSideInset, pinsDockToBottom: true)
                .padding(.bottom, layout.bottomDockPadding(safeBottom: safeBottom))
        }
    }

    private func welcomeInteractiveStack(
        layout: WelcomeZoneLayout,
        dockSideInset: CGFloat,
        pinsDockToBottom: Bool
    ) -> some View {
        // Brand → outcome → trust → action, read top to bottom in that order (also the VoiceOver order).
        // The brand sits on the hero block as its lockup rather than alone in the corner; the block rides
        // high over the darkened footage, the open doorway shows above it, and the dock owns the foot.
        VStack(alignment: .leading, spacing: 0) {
            if pinsDockToBottom {
                // Photo above the lockup. Capped, so on tall phones the rest of the slack falls between
                // the slip and the dock and the hero block stays high; on short phones it gives way first.
                Spacer(minLength: 6)
                    .frame(maxHeight: layout.maxTopBreathing)
            } else {
                Color.clear.frame(height: 16)
            }

            brandIdentityRow

            primaryCopyBlock
                .padding(.top, layout.brandToHeadlineGap)

            // The room itself becomes the evidence: no card, no sample record (WelcomeHero).
            WelcomeHero(isCompact: layout.isCompactHeight || usesAccessibilityScrollLayout,
                        reveal: heroReveal, coordinateSpace: Self.space)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, layout.copyToSlipGap)

            if pinsDockToBottom {
                Spacer(minLength: layout.slipToDockGap)
            } else {
                Color.clear.frame(height: layout.slipToDockGap)
            }

            bottomLaunchDock(isCompact: layout.isCompactHeight && !usesAccessibilityScrollLayout)
                .padding(.horizontal, dockSideInset)
        }
        .padding(.horizontal, contentPadding)
        // The poster composition is fixed through xxxLarge (as it always was); accessibility sizes
        // get the scrolling layout and real growth, to the same ceiling as the app's sheets.
        .dynamicTypeSize(usesAccessibilityScrollLayout ? ...DynamicTypeSize.accessibility2 : ...DynamicTypeSize.large)
    }

    private var welcomeBackdropAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.9)
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

    /// Navigation away is immediate: the auth surface starts presenting on the tap itself. The button's
    /// own press style (`MMLightPressStyle`) carries the tactile response.
    private func launchAuth(mode: AuthContainerView.Mode) {
        authInitialMode = mode
        authPresentationID = UUID()

        if reduceMotion {
            showAuth = true
            return
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            showAuth = true
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

    /// The app wordmark, a step larger than on the dark headers, set as the hero block's lockup.
    /// Read once as "MoveMark" (the mark itself is hidden inside `MMWordmark`).
    private var brandIdentityRow: some View {
        MMWordmark(size: wordmarkSize)
            .frame(minHeight: 44, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("MoveMark")
    }

    // MARK: - Copy (hero explains; dock launches)

    private var primaryCopyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Two Text views rather than one wrapped string, so the break is editorial rather than a
            // function of device width — the headline is never one line, on any screen.
            VStack(alignment: .leading, spacing: -2) {
                Text(MoveMarkGrowthCopy.welcomeHeadlineLead)
                Text(MoveMarkGrowthCopy.welcomeHeadlineTail)
            }
            .mmFont(40, .semibold)
            .tracking(-0.8)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.22), radius: 12, y: 2)
            // Fixed composition: one editorial line per Text through xxxLarge.
            // Accessibility sizes: let the lines wrap and grow — scroll carries the overflow.
            .modifier(WelcomeHeadlineDynamicTypeFit(allowsWrapping: usesAccessibilityScrollLayout))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(MoveMarkGrowthCopy.welcomeHeadline)
            .accessibilityAddTraits(.isHeader)

            Text(MoveMarkGrowthCopy.welcomeBody)
                .mmFont(16)
                .foregroundStyle(.white.opacity(0.78))
                // Four lines on regular phones, and over the darker centre-left of the footage rather
                // than the lit curtain on the right of wide screens.
                .frame(maxWidth: 340, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Bottom launch dock

    /// The screen's one primary action (lime, as everywhere in the app) and a quiet way to sign in.
    private func bottomLaunchDock(isCompact: Bool) -> some View {
        VStack(spacing: 0) {
            MMPrimaryButton(title: MoveMarkGrowthCopy.welcomeCTA) {
                MMHaptics.light()
                MoveMarkAnalytics.track(.welcomeStartProofTapped)
                launchAuth(mode: .signUp)
            }
            .accessibilityIdentifier("welcome.primaryCTA")

            if showsSocial {
                WelcomeSocialActions(busyProvider: socialBusy) { startSocialSignIn($0) }
                    .padding(.top, 14)
                if let socialError {
                    MMNotice(message: socialError).padding(.top, 8)
                }
            }

            signInButton
                .padding(.top, 4)

            // Short screens with the social block need this line's height; the default layout keeps it.
            if !(showsSocial && isCompact) {
                Text(MoveMarkGrowthCopy.welcomeTrustLine)
                    .mmFont(12.5)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
        }
    }

    private var signInButton: some View {
        Button {
            MMHaptics.soft()
            MoveMarkAnalytics.track(.welcomeSignInTapped)
            launchAuth(mode: .signIn)
        } label: {
            Text(MoveMarkGrowthCopy.welcomeSecondaryCTA)
                .mmFont(15.5, .semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityIdentifier("welcome.signIn")
    }

    /// One quiet fade of the whole page, once, then the hero's single reveal. Reduce Motion: both are simply there.
    private func playEntrance() {
        guard !entranceVisible else { return }
        if reduceMotion {
            entranceVisible = true
            heroReveal = 1
            return
        }
        withAnimation(.easeOut(duration: 0.4)) {
            entranceVisible = true
        }
        withAnimation(.easeInOut(duration: 0.8).delay(0.45)) {
            heroReveal = 1
        }
    }

    /// Live: a real session through `SessionManager`, and the root moves on by itself. Probe: signs in to the isolated
    /// project, shows the identity, signs out; never the app session. A cancelled sheet is silent in both.
    private func startSocialSignIn(_ provider: SocialProvider) {
        let mode = SocialSignInConfig.mode
        guard socialBusy == nil, mode != .off else { return }
        MMHaptics.light()
        socialError = nil
        socialBusy = provider
        Task { @MainActor in
            defer { socialBusy = nil }
            do {
                switch mode {
                case .live:
                    try await sessionManager?.signInWithSocial(provider)
                case .probe(let url):
                    probeResult = try await SocialProbeRunner().run(provider, probeURL: url)
                case .off:
                    break
                }
            } catch SocialSignInError.cancelled {
                // Closed the sheet; nothing to say.
            } catch NeonAuthError.rejected(let code, let message) {
                let shown = NeonAuthError.rejected(code: code, message: message).localizedDescription
                socialError = "\(shown) [\(code ?? "no code")]"
            } catch {
                socialError = error.localizedDescription
            }
        }
    }
}

extension WelcomeScreen {
    /// Snapshot tests only: the settled poster composition — what Reduce Motion shows — without the video
    /// layer or the entrance. In an extension so `WelcomeScreen()` stays the production init.
    init(previewSettled: Void, reduceMotion: Bool = false, showsSocial: Bool = false) {
        self.init()
        showsVideo = false
        forcesReduceMotion = reduceMotion
        socialOverride = showsSocial
        _entranceVisible = State(initialValue: true)
        _heroReveal = State(initialValue: 1)
    }
}

// MARK: - Zone layout

private struct WelcomeZoneLayout {
    /// Most photo the lockup may leave above itself; the rest of the slack goes above the dock.
    let maxTopBreathing: CGFloat
    let brandToHeadlineGap: CGFloat
    let copyToSlipGap: CGFloat
    let slipToDockGap: CGFloat
    /// Drives the proof artifact's density. Only the slip responds to this — type never shrinks for it.
    let isCompactHeight: Bool

    init(screenHeight: CGFloat, safeTop: CGFloat, safeBottom: CGFloat) {
        // Available vertical space, not a device check: an SE is short because of what it
        // leaves the layout, and a model list would be wrong again on the next phone. This is
        // the safe-area-excluded height, so the measured split is SE 647 and 13 mini 728 on the
        // compact side, iPhone 16 759 and 17 Pro Max 860 on the regular side.
        isCompactHeight = screenHeight < 700
        maxTopBreathing = (screenHeight * 0.135).rounded()
        brandToHeadlineGap = 18
        copyToSlipGap = isCompactHeight ? 16 : 20
        slipToDockGap = 22
    }

    func bottomDockPadding(safeBottom: CGFloat) -> CGFloat {
        max(28, safeBottom + 14)
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
