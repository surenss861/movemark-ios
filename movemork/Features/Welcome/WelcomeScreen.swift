//
//  WelcomeScreen.swift
//  movemork
//
//  MoveMark — Clean green + white welcome. Proof-first hero, obvious CTA.
//

import SwiftUI

struct WelcomeScreen: View {
    @State private var showAuth = false
    @State private var authInitialMode: AuthContainerView.Mode = .signUp
    @State private var heroRevealed = false

    var body: some View {
        NavigationStack {
            ZStack {
                welcomeBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 28)

                    heroCardCluster
                        .padding(.horizontal, 24)
                        .opacity(heroRevealed ? 1 : 0.9)
                        .offset(y: heroRevealed ? 0 : 10)

                    Spacer(minLength: 12)

                    bottomContent
                        .padding(.horizontal, 26)
                        .padding(.bottom, 32)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.55)) {
                    heroRevealed = true
                }
            }
            .navigationDestination(isPresented: $showAuth) {
                AuthContainerView(initialMode: authInitialMode)
            }
        }
    }

    private var welcomeBackground: some View {
        ZStack {
            MoveMarkTheme.Colors.background

            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.mint.opacity(0.85),
                    MoveMarkTheme.Colors.background,
                    MoveMarkTheme.Colors.background
                ],
                center: .top,
                startRadius: 40,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.primary.opacity(0.12),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 280
            )
            .offset(x: 40, y: 80)
        }
    }

    private var heroCardCluster: some View {
        ZStack {
            protectedDepositCard
                .offset(x: 72, y: -8)
                .rotationEffect(.degrees(3))

            proofPhoneCard
                .offset(x: -12, y: 24)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
    }

    private var proofPhoneCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image("welcome-kitchen-main")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .clipped()

                LinearGradient(
                    colors: [.clear, MoveMarkTheme.Colors.textPrimary.opacity(0.2)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 140)

                HStack {
                    Text("Kitchen")
                        .font(MoveMarkTheme.Typography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MoveMarkTheme.Colors.primary.opacity(0.92))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    proofScoreRing
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Proof score")
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        Text("Strong")
                            .font(MoveMarkTheme.Typography.subheadlineMedium)
                            .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen)
                    }
                    Spacer()
                    Text("12 photos")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }

                HStack(spacing: 6) {
                    miniThumb("welcome-kitchen-2")
                    miniThumb("welcome-kitchen-3")
                    miniThumb("welcome-kitchen-4")
                    Text("+8")
                        .font(MoveMarkTheme.Typography.caption)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(MoveMarkTheme.Colors.mint.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(14)
            .background(MoveMarkTheme.Colors.panel)
        }
        .frame(width: 248)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 1)
        )
        .shadow(color: MoveMarkTheme.Colors.textPrimary.opacity(0.08), radius: 24, y: 12)
        .rotationEffect(.degrees(-2.5))
    }

    private var proofScoreRing: some View {
        ZStack {
            Circle()
                .stroke(MoveMarkTheme.Colors.mint, lineWidth: 4)
                .frame(width: 40, height: 40)
            Circle()
                .trim(from: 0, to: 0.82)
                .stroke(MoveMarkTheme.Colors.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 40, height: 40)
            Text("82")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen)
        }
    }

    private var protectedDepositCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
                Spacer()
                MMPill(text: "Protected", tone: .success)
            }

            Text("$2,400")
                .font(MoveMarkTheme.Typography.cardValue)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text("Deposit protected")
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            HStack(spacing: 12) {
                statMini("24", "Photos")
                statMini("3", "Issues")
            }
        }
        .padding(16)
        .frame(width: 188)
        .background(MoveMarkTheme.Colors.panelAlt)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 1)
        )
        .shadow(color: MoveMarkTheme.Colors.textPrimary.opacity(0.06), radius: 16, y: 8)
    }

    private func statMini(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            Text(label)
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
    }

    private func miniThumb(_ name: String) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 0.8)
            )
    }

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Get your deposit back.")
                .font(MoveMarkTheme.Typography.heroLarge)
                .tracking(-0.8)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Take photos now. Make a report later.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .lineSpacing(3)
                .padding(.top, 10)
                .padding(.bottom, 22)

            MMButton(title: "Start proof") {
                MMHaptics.soft()
                authInitialMode = .signUp
                showAuth = true
            }

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text("Already have an account?")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                Button {
                    MMHaptics.soft()
                    authInitialMode = .signIn
                    showAuth = true
                } label: {
                    Text("Sign in")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
            .padding(.top, 14)
        }
    }
}
