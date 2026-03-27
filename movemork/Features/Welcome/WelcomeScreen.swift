//
//  WelcomeScreen.swift
//  movemork
//
//  MoveMark — Premium dark welcome. Local kitchen assets, SF Pro, atmospheric background.
//

import SwiftUI

struct WelcomeScreen: View {
    @State private var showAuth = false
    @State private var authInitialMode: AuthContainerView.Mode = .signUp

    var body: some View {
        NavigationStack {
            ZStack {
                MoveMarkTheme.Colors.background
                    .ignoresSafeArea()

                backgroundAtmosphere

                VStack(spacing: 0) {
                    Spacer(minLength: 42)

                    heroComposition
                        .padding(.horizontal, 18)

                    Spacer(minLength: 18)

                    bottomContent
                        .padding(.horizontal, 26)
                        .padding(.bottom, 30)
                }
            }
            .navigationDestination(isPresented: $showAuth) {
                AuthContainerView(initialMode: authInitialMode)
            }
        }
    }

    private var backgroundAtmosphere: some View {
        ZStack {
            // Warmer gold glow upper-left
            RadialGradient(
                colors: [
                    Color(red: 196/255, green: 164/255, blue: 108/255).opacity(0.14),
                    Color(red: 196/255, green: 164/255, blue: 108/255).opacity(0.04),
                    .clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 280
            )
            .offset(x: -80, y: -40)

            // Deeper emerald glow lower-right
            RadialGradient(
                colors: [
                    Color(red: 27/255, green: 94/255, blue: 59/255).opacity(0.22),
                    Color(red: 27/255, green: 94/255, blue: 59/255).opacity(0.06),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 360
            )
            .offset(x: 60, y: 120)

            // Soft center haze behind hero
            RadialGradient(
                colors: [
                    Color.white.opacity(0.03),
                    .clear
                ],
                center: .center,
                startRadius: 60,
                endRadius: 220
            )

            // Vertical fade into background
            LinearGradient(
                colors: [
                    Color.clear,
                    MoveMarkTheme.Colors.background.opacity(0.2),
                    MoveMarkTheme.Colors.background.opacity(0.85),
                    MoveMarkTheme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Vignette
            RadialGradient(
                colors: [
                    .clear,
                    .clear,
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.35)
                ],
                center: .center,
                startRadius: 120,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private var heroComposition: some View {
        ZStack {
            mainEvidenceCard
                .rotationEffect(.degrees(-2))
                .frame(maxWidth: .infinity, alignment: .leading)

            accentDisputeCard
                .offset(x: 92, y: 108)
        }
        .frame(height: 414)
    }

    private var mainEvidenceCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 22/255, green: 21/255, blue: 20/255))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 34, y: 16)

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Image("welcome-kitchen-main")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 162)
                        .clipped()

                    LinearGradient(
                        colors: [
                            .black.opacity(0.12),
                            .clear,
                            .black.opacity(0.5),
                            .black.opacity(0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    HStack {
                        chip("Kitchen", filled: true)

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(MoveMarkTheme.Typography.caption)
                            Text("12")
                                .font(MoveMarkTheme.Typography.caption)
                        }
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.38))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .frame(height: 162)
                .clipped()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        thumbImage("welcome-kitchen-2", selected: true)
                        thumbImage("welcome-kitchen-3", selected: false)
                        thumbImage("welcome-kitchen-4", selected: false)
                        thumbImage("welcome-kitchen-5", selected: false)

                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Text("+8")
                                    .font(MoveMarkTheme.Typography.caption)
                                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            )
                    }

                    HStack(spacing: 8) {
                        tag("Water damage", tone: .amber)
                        tag("Chipped paint", tone: .green)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONDITION")
                            .font(MoveMarkTheme.Typography.caption)
                            .tracking(1.2)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                        HStack(spacing: 5) {
                            ForEach(0..<5, id: \.self) { idx in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(idx < 3 ? Color(red: 217/255, green: 119/255, blue: 6/255) : Color.white.opacity(0.08))
                                    .frame(width: 22, height: 4)
                            }
                        }
                    }

                    HStack {
                        Text("Apr 14, 2025 · 5:42 PM")
                        Spacer()
                        Text("MM-0414-KT")
                    }
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 18)
                .background(Color(red: 18/255, green: 17/255, blue: 16/255))
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .frame(width: 292)
    }

    private var accentDisputeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DISPUTE")
                    .font(MoveMarkTheme.Typography.caption)
                    .tracking(1.2)
                    .foregroundStyle(MoveMarkTheme.Colors.accent)

                Spacer()

                Circle()
                    .fill(MoveMarkTheme.Colors.primary)
                    .frame(width: 8, height: 8)
            }

            Text("$2,400")
                .font(MoveMarkTheme.Typography.cardTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text("Security deposit withheld")
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            Text("CASE READY")
                .font(MoveMarkTheme.Typography.caption)
                .tracking(1.2)
                .foregroundStyle(MoveMarkTheme.Colors.primary)

            VStack(spacing: 6) {
                HStack {
                    Text("Evidence strength")
                        .font(MoveMarkTheme.Typography.caption)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    Spacer()
                    Text("Strong")
                        .font(MoveMarkTheme.Typography.caption)
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        MoveMarkTheme.Colors.primary,
                                        MoveMarkTheme.Colors.primary.opacity(0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * 0.82)
                    }
                }
                .frame(height: 6)
            }

            Divider()
                .overlay(Color.white.opacity(0.06))

            HStack {
                stat("24", "Photos")
                Spacer()
                stat("3", "Issues")
                Spacer()
                stat("4", "Docs")
            }
        }
        .padding(18)
        .frame(width: 235)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(red: 18/255, green: 17/255, blue: 16/255).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
        .rotationEffect(.degrees(2.4))
    }

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            MoveMarkTheme.Colors.accent,
                            MoveMarkTheme.Colors.accent.opacity(0.35)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 38, height: 2)
                .clipShape(Capsule())
                .padding(.bottom, 16)

            Text("Protect your deposit.")
                .font(MoveMarkTheme.Typography.hero)
                .tracking(-1.2)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .padding(.bottom, 2)

            Text("Prove your case.")
                .font(MoveMarkTheme.Typography.hero)
                .tracking(-1.2)
                .foregroundStyle(MoveMarkTheme.Colors.primary)
                .padding(.bottom, 12)

            Text("Build your proof trail before anything gets disputed.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 24)

            MMButton(
                title: "Get started",
                action: {
                    authInitialMode = .signUp
                    showAuth = true
                },
                kind: .primary,
                size: .hero
            )
            .padding(.bottom, 16)

            HStack(spacing: 5) {
                Spacer()
                Text("Already have an account?")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                Button {
                    authInitialMode = .signIn
                    showAuth = true
                } label: {
                    Text("Sign in")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                }
                Spacer()
            }
        }
    }

    private func chip(_ title: String, filled: Bool = false) -> some View {
        Text(title)
            .font(MoveMarkTheme.Typography.caption)
            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(filled ? 0.48 : 0.38))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func thumbImage(_ name: String, selected: Bool) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        selected ? MoveMarkTheme.Colors.accent : Color.white.opacity(0.05),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
    }

    private enum TagTone {
        case amber
        case green
    }

    private func tag(_ title: String, tone: TagTone) -> some View {
        let fg: Color = tone == .amber
            ? Color(red: 217/255, green: 119/255, blue: 6/255)
            : MoveMarkTheme.Colors.primary

        let bg: Color = tone == .amber
            ? Color(red: 217/255, green: 119/255, blue: 6/255).opacity(0.12)
            : MoveMarkTheme.Colors.primary.opacity(0.12)

        return Text(title)
            .font(MoveMarkTheme.Typography.caption)
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(MoveMarkTheme.Typography.cardTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(label)
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
    }
}
