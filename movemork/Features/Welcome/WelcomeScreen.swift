//
//  WelcomeScreen.swift
//  movemork
//
//  MoveMark — Proof Passport intro (one object, one chip, one action).
//

import SwiftUI

struct WelcomeScreen: View {
    @State private var showAuth = false
    @State private var authInitialMode: AuthContainerView.Mode = .signUp
    @State private var bgVisible = false
    @State private var heroVisible = false
    @State private var copyVisible = false
    @State private var ctaVisible = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let horizontalPadding: CGFloat = 28

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let passportWidth = geo.size.width - (horizontalPadding * 2)
                let heroHeight = min(geo.size.height * 0.44, 320)

                ZStack {
                    WelcomeVaultBackground()
                        .opacity(bgVisible ? 1 : 0)

                    VStack(spacing: 0) {
                        heroZone(
                            width: passportWidth,
                            height: heroHeight,
                            topSafe: geo.safeAreaInsets.top
                        )

                        copyZone
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 22)

                        Spacer(minLength: 12)

                        actionZone
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, max(24, geo.safeAreaInsets.bottom + 12))
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
        let d: Double = reduceMotion ? 0 : 1
        withAnimation(.easeOut(duration: 0.5 * d)) { bgVisible = true }
        withAnimation(.easeOut(duration: 0.65 * d).delay(reduceMotion ? 0 : 0.06)) { heroVisible = true }
        withAnimation(.easeOut(duration: 0.5 * d).delay(reduceMotion ? 0 : 0.18)) { copyVisible = true }
        withAnimation(.easeOut(duration: 0.45 * d).delay(reduceMotion ? 0 : 0.28)) { ctaVisible = true }
    }

    // MARK: - Hero

    private func heroZone(width: CGFloat, height: CGFloat, topSafe: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            WelcomeReportBackingCard()
                .frame(width: width)
                .opacity(heroVisible ? 1 : 0)
                .offset(x: heroVisible ? 0 : 8, y: heroVisible ? -8 : 4)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(0.1), value: heroVisible)

            WelcomeProofPassportCard(width: width)
                .opacity(heroVisible ? 1 : 0)
                .offset(y: heroVisible ? 0 : (reduceMotion ? 0 : 18))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.65).delay(0.06), value: heroVisible)

            WelcomeProtectionChip()
                .offset(x: width - 168, y: -6)
                .opacity(heroVisible ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.14), value: heroVisible)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, max(12, topSafe + 6))
    }

    // MARK: - Copy

    private var copyZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Get your deposit back.")
                .font(.system(size: 38, weight: .bold))
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
        .offset(y: copyVisible ? 0 : (reduceMotion ? 0 : 10))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.18), value: copyVisible)
    }

    // MARK: - Action

    private var actionZone: some View {
        VStack(spacing: 0) {
            MMButton(
                title: "Start proof",
                action: {
                    MMHaptics.soft()
                    authInitialMode = .signUp
                    showAuth = true
                },
                showsTrailingArrow: true
            )
            .opacity(ctaVisible ? 1 : 0)
            .offset(y: ctaVisible ? 0 : (reduceMotion ? 0 : 8))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.28), value: ctaVisible)

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
            .padding(.top, 14)
            .opacity(ctaVisible ? 1 : 0)
        }
    }
}
