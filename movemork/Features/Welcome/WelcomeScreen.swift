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
                    MMEmeraldBackground(emphasizesHeroZone: false, emphasizesCTABloom: false)

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

    // MARK: - Brand

    private var brandIdentityRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("MoveMarkLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 35, height: 35)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("MoveMark")
                .font(.system(size: 20.5, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Spacer(minLength: 0)
        }
        .opacity(cardVisible ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: cardVisible)
    }

    // MARK: - Copy (hero explains; dock launches)

    private var primaryCopyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prove what was already there.")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.7)
                .lineSpacing(2)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.92)
                .fixedSize(horizontal: false, vertical: true)

            Text("Take room photos before you unpack. Turn them into a report when you need it.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.98))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(copyVisible ? 1 : 0)
        .offset(y: copyVisible ? 0 : 8)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.44).delay(0.22), value: copyVisible)
    }

    // MARK: - Bottom launch dock

    private var bottomLaunchDock: some View {
        VStack(spacing: 0) {
            MMButton(
                title: "Start move-in proof",
                action: { launchAuth(mode: .signUp) },
                showsTrailingArrow: true
            )
            .scaleEffect(launchCTAPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: launchCTAPressed)

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
