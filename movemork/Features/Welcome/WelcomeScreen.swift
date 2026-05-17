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

    private let contentPadding: CGFloat = 20
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
                let cardWidth = min(geo.size.width - contentPadding * 2, 420)
                let dockSideInset = max(0, launchDockHorizontalInset - contentPadding)

                ZStack {
                    MMEmeraldBackground(emphasizesHeroZone: false, emphasizesCTABloom: false)

                    VStack(alignment: .leading, spacing: 0) {
                        brandIdentityRow
                            .padding(.bottom, layout.brandToHeroGap)

                        WelcomeDepositCaseFile(
                            maxWidth: cardWidth,
                            heroHeight: layout.heroHeight,
                            cardVisible: cardVisible,
                            tagsVisible: tagsVisible
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: layout.heroHeight)

                        headlineBlock
                            .padding(.top, layout.heroToCopyGap)

                        Spacer(minLength: layout.minFlexGap)

                        bottomLaunchDock
                            .padding(.horizontal, dockSideInset)
                    }
                    .padding(.horizontal, contentPadding)
                    .padding(.top, layout.topPadding)
                    .padding(.bottom, layout.bottomDockPadding(safeBottom: geo.safeAreaInsets.bottom))
                }
            }
            .onAppear { playEntrance() }
            .fullScreenCover(isPresented: $showAuth) {
                AuthContainerView(initialMode: authInitialMode)
                    .id(authPresentationID)
            }
        }
    }

    private func launchAuth(mode: AuthContainerView.Mode) {
        MMHaptics.soft()
        authInitialMode = mode
        authPresentationID = UUID()
        if reduceMotion {
            showAuth = true
            return
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            launchCTAPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showAuth = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                launchCTAPressed = false
            }
        }
    }

    // MARK: - Brand

    private var brandIdentityRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("MoveMarkLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text("MoveMark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Spacer(minLength: 0)
        }
        .opacity(cardVisible ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: cardVisible)
    }

    // MARK: - Copy (hero explains; dock launches)

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prove what was already there.")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.7)
                .lineSpacing(2)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.92)
                .fixedSize(horizontal: false, vertical: true)

            Text("Take move-in photos now. Make a report when you need it.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.98))
                .fixedSize(horizontal: false, vertical: true)

            Text("Old damage becomes saved proof.")
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
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
            .padding(.top, 20)
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
    let heroHeight: CGFloat
    let topPadding: CGFloat
    let brandToHeroGap: CGFloat
    let heroToCopyGap: CGFloat
    let minFlexGap: CGFloat

    init(screenHeight: CGFloat, safeTop: CGFloat, safeBottom: CGFloat) {
        let usable = screenHeight - safeTop - safeBottom - 12
        heroHeight = usable * 0.38
        topPadding = max(4, safeTop - 71)
        brandToHeroGap = 14
        heroToCopyGap = 20
        minFlexGap = 16
    }

    func bottomDockPadding(safeBottom: CGFloat) -> CGFloat {
        max(38, safeBottom + 34)
    }
}
