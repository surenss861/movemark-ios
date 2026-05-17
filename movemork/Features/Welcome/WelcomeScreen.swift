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

    @State private var cardVisible = false
    @State private var tagsVisible = false
    @State private var copyVisible = false
    @State private var ctaVisible = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let contentPadding: CGFloat = 20

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let layout = WelcomeZoneLayout(
                    screenHeight: geo.size.height,
                    safeTop: geo.safeAreaInsets.top,
                    safeBottom: geo.safeAreaInsets.bottom
                )
                let cardWidth = min(geo.size.width - contentPadding * 2, 420)

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
                            .frame(height: layout.copyHeight, alignment: .topLeading)
                            .padding(.top, layout.heroToCopyGap)

                        ctaBlock
                            .frame(height: layout.ctaHeight, alignment: .top)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, contentPadding)
                    .padding(.top, layout.topPadding)
                    .padding(.bottom, max(8, geo.safeAreaInsets.bottom))
                }
            }
            .onAppear { playEntrance() }
            .navigationDestination(isPresented: $showAuth) {
                AuthContainerView(initialMode: authInitialMode)
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

    // MARK: - Copy

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(copyVisible ? 1 : 0)
        .offset(y: copyVisible ? 0 : 8)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.44).delay(0.22), value: copyVisible)
    }

    // MARK: - CTA

    private var ctaBlock: some View {
        VStack(spacing: 0) {
            Text("Old damage becomes saved proof.")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.95))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 11)

            MMButton(
                title: "Start move-in proof",
                action: {
                    MMHaptics.soft()
                    authInitialMode = .signUp
                    showAuth = true
                },
                showsTrailingArrow: true
            )
            .padding(.top, 4)

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text("Already have an account?")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
                Button {
                    MMHaptics.soft()
                    authInitialMode = .signIn
                    showAuth = true
                } label: {
                    Text("Sign in")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.95))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
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

// MARK: - Zone layout (percent of usable screen)

private struct WelcomeZoneLayout {
    let heroHeight: CGFloat
    let copyHeight: CGFloat
    let ctaHeight: CGFloat
    let topPadding: CGFloat
    let brandToHeroGap: CGFloat
    let heroToCopyGap: CGFloat

    init(screenHeight: CGFloat, safeTop: CGFloat, safeBottom: CGFloat) {
        let usable = screenHeight - safeTop - safeBottom - 12
        heroHeight = usable * 0.38
        copyHeight = usable * 0.20
        ctaHeight = usable * 0.18
        // Pull brand + hero up ~60pt vs prior safeTop+4 layout.
        topPadding = max(4, safeTop - 56)
        brandToHeroGap = 14
        heroToCopyGap = 20
    }
}
