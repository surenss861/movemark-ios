//
//  WelcomeScreen.swift
//  movemork
//
//  MoveMark — Dark evidence desk welcome (deposit case file, no photo hero).
//

import SwiftUI

struct WelcomeScreen: View {
    @State private var showAuth = false
    @State private var authInitialMode: AuthContainerView.Mode = .signUp

    @State private var deskVisible = false
    @State private var cardVisible = false
    @State private var statsVisible = false
    @State private var scanlineTrigger = 0
    @State private var copyVisible = false
    @State private var ctaVisible = false
    @State private var ctaGlintTrigger = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let contentPadding: CGFloat = 20

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let maxCard = min(geo.size.width - contentPadding * 2, 420)

                ZStack {
                    MMEmeraldBackground(emphasizesHeroZone: true, emphasizesCTABloom: false)

                    WelcomeEvidenceDeskRuledPaper()
                        .opacity(deskVisible ? 1 : 0)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.55), value: deskVisible)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            brandWordmarkChip
                                .padding(.top, max(4, geo.safeAreaInsets.top - 28))

                            WelcomeDepositCaseFile(
                                maxWidth: maxCard,
                                cardVisible: cardVisible,
                                statsVisible: statsVisible,
                                scanlineTrigger: scanlineTrigger
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)

                            headlineBlock
                                .padding(.top, 24)

                            ctaBlock(glowWidth: min(420, geo.size.width * 0.96))
                                .padding(.top, 22)
                                .padding(.bottom, max(28, geo.safeAreaInsets.bottom + 20))
                        }
                        .padding(.horizontal, contentPadding)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .onAppear {
                playEntrance()
            }
            .navigationDestination(isPresented: $showAuth) {
                AuthContainerView(initialMode: authInitialMode)
            }
        }
    }

    private var brandWordmarkChip: some View {
        HStack(spacing: 7) {
            Image("MoveMarkLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
                )
            Text("MoveMark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.96))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(MoveMarkTheme.Colors.card.opacity(0.88))
        )
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            MoveMarkTheme.Colors.limeAccent.opacity(0.18),
                            MoveMarkTheme.Colors.cardStroke.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.85
                )
        )
        .shadow(color: Color.black.opacity(0.32), radius: 8, y: 3)
        .opacity(deskVisible ? 1 : 0)
        .offset(y: deskVisible ? 0 : 6)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: deskVisible)
    }

    private func playEntrance() {
        if reduceMotion {
            deskVisible = true
            cardVisible = true
            statsVisible = true
            copyVisible = true
            ctaVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.5)) { deskVisible = true }
        withAnimation(.easeOut(duration: 0.52).delay(0.06)) { cardVisible = true }
        withAnimation(.easeOut(duration: 0.44).delay(0.14)) { statsVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            scanlineTrigger += 1
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.22)) { copyVisible = true }
        withAnimation(.easeOut(duration: 0.42).delay(0.32)) { ctaVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            ctaGlintTrigger += 1
        }
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Get your deposit back.")
                .font(.system(size: 38, weight: .bold))
                .tracking(-0.9)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Take photos now. Make a report later.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.98))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(copyVisible ? 1 : 0)
        .offset(y: copyVisible ? 0 : 6)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.22), value: copyVisible)
    }

    private func ctaBlock(glowWidth: CGFloat) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                MoveMarkTheme.Colors.primary.opacity(0.08),
                                MoveMarkTheme.Colors.primary.opacity(0.03),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 96
                        )
                    )
                    .frame(width: glowWidth, height: 68)
                    .offset(y: 8)
                    .opacity(ctaVisible ? 1 : 0)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                MoveMarkTheme.Colors.limeAccent.opacity(0.025),
                                .clear
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 48
                        )
                    )
                    .frame(width: 160, height: 36)
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
                .mmCTAGlint(trigger: reduceMotion ? 0 : ctaGlintTrigger)
            }

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
                        .foregroundStyle(MoveMarkTheme.Colors.limeAccent)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
        }
        .opacity(ctaVisible ? 1 : 0)
        .offset(y: ctaVisible ? 0 : 6)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.42).delay(0.32), value: ctaVisible)
    }
}
