//
//  WelcomeScreen.swift
//  movemork
//
//  MoveMark — Proof dossier + product story intro.
//

import SwiftUI

struct WelcomeScreen: View {
    @State private var showAuth = false
    @State private var authInitialMode: AuthContainerView.Mode = .signUp
    @State private var bgVisible = false
    @State private var heroVisible = false
    @State private var copyVisible = false
    @State private var railVisible = false
    @State private var ctaVisible = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sidePadding: CGFloat = 20

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let contentWidth = geo.size.width - (sidePadding * 2)

                ZStack {
                    WelcomeVaultBackground()
                        .opacity(bgVisible ? 1 : 0)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            brandLine
                                .padding(.horizontal, sidePadding)
                                .padding(.top, max(8, geo.safeAreaInsets.top + 2))

                            heroBlock(width: contentWidth, topInset: 0)
                                .padding(.top, 10)

                            headlineBlock
                                .padding(.horizontal, sidePadding)
                                .padding(.top, 16)

                            WelcomeProofFlowRail()
                                .padding(.horizontal, sidePadding)
                                .padding(.top, 22)
                                .opacity(railVisible ? 1 : 0)
                                .offset(y: railVisible ? 0 : 8)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.24), value: railVisible)

                            ctaBlock
                                .padding(.horizontal, sidePadding)
                                .padding(.top, 26)
                                .padding(.bottom, max(16, geo.safeAreaInsets.bottom + 8))
                        }
                    }
                }
            }
            .onAppear { playEntrance() }
            .navigationDestination(isPresented: $showAuth) {
                AuthContainerView(initialMode: authInitialMode)
            }
        }
    }

    private func playEntrance() {
        if reduceMotion {
            bgVisible = true
            heroVisible = true
            copyVisible = true
            railVisible = true
            ctaVisible = true
            return
        }
        withAnimation(.easeOut(duration: 0.5)) { bgVisible = true }
        withAnimation(.easeOut(duration: 0.65).delay(0.05)) { heroVisible = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.18)) { copyVisible = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.26)) { railVisible = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.34)) { ctaVisible = true }
    }

    private var brandLine: some View {
        Text("Deposit proof starts here")
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(MoveMarkTheme.Colors.proofMint.opacity(0.85))
            .opacity(heroVisible ? 1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.04), value: heroVisible)
    }

    private func heroBlock(width: CGFloat, topInset: CGFloat) -> some View {
        WelcomeProofDossierHero(width: width)
            .padding(.horizontal, sidePadding)
            .opacity(heroVisible ? 1 : 0)
            .offset(y: heroVisible ? 0 : 14)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.65).delay(0.05), value: heroVisible)
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
        .offset(y: copyVisible ? 0 : 8)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.18), value: copyVisible)
    }

    private var ctaBlock: some View {
        VStack(spacing: 12) {
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                MoveMarkTheme.Colors.primary.opacity(0.22),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 120
                        )
                    )
                    .frame(height: 56)
                    .offset(y: 8)
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
        .offset(y: ctaVisible ? 0 : 8)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.34), value: ctaVisible)
    }
}
