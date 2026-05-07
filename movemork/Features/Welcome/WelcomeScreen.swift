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
    @State private var heroRevealed = false

    var body: some View {
        NavigationStack {
            ZStack {
                MoveMarkTheme.Colors.background
                    .ignoresSafeArea()

                backgroundAtmosphere

                welcomeFilmGrain
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 34)

                    heroComposition
                        .padding(.horizontal, 20)
                        .opacity(heroRevealed ? 1 : 0.86)
                        .offset(y: heroRevealed ? 0 : 8)

                    Spacer(minLength: 8)

                    bottomContent
                        .padding(.horizontal, 26)
                        .padding(.bottom, 28)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) {
                    heroRevealed = true
                }
            }
            .navigationDestination(isPresented: $showAuth) {
                AuthContainerView(initialMode: authInitialMode)
            }
        }
    }

    private var backgroundAtmosphere: some View {
        ZStack {
            // Near-black base with deep emerald/navy lift.
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.015, green: 0.035, blue: 0.030),
                    Color(red: 0.012, green: 0.022, blue: 0.027),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Hero-adjacent emerald glow.
            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.primary.opacity(0.24),
                    MoveMarkTheme.Colors.primary.opacity(0.08),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .blur(radius: 52)
            .offset(x: 36, y: -8)

            // Secondary charcoal/navy atmosphere to avoid flat black.
            RadialGradient(
                colors: [
                    Color(red: 0.05, green: 0.10, blue: 0.09).opacity(0.22),
                    .clear
                ],
                center: .bottom,
                startRadius: 90,
                endRadius: 520
            )
            .blur(radius: 28)
            .offset(y: 42)

            // Soft bottom bloom to anchor CTA region.
            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.primary.opacity(0.16),
                    MoveMarkTheme.Colors.primary.opacity(0.06),
                    .clear
                ],
                center: .bottom,
                startRadius: 24,
                endRadius: 260
            )
            .blur(radius: 38)
            .offset(y: 122)

            // Ultra-faint vault grid / blueprint lines.
            Canvas { context, size in
                let spacing: CGFloat = 32
                let lineColor = Color.white.opacity(0.031)
                var x: CGFloat = 0
                while x <= size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.45)
                    x += spacing
                }

                var y: CGFloat = 0
                while y <= size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.45)
                    y += spacing
                }
            }
            .mask(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.45),
                        Color.white.opacity(0.15),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(0.52)

            // Cinematic edge falloff / vignette.
            RadialGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.26),
                    Color.black.opacity(0.5)
                ],
                center: .center,
                startRadius: 115,
                endRadius: 460
            )
            .ignoresSafeArea()
        }
    }

    /// Very subtle film grain so the background feels finished, not flat black.
    private var welcomeFilmGrain: some View {
        Canvas { context, size in
            let step: CGFloat = 5
            var gx = 0
            while CGFloat(gx) * step < size.width {
                var gy = 0
                while CGFloat(gy) * step < size.height {
                    let hash = (gx &* 31) &+ (gy &* 17)
                    if hash % 13 == 0 {
                        let r = CGRect(x: CGFloat(gx) * step, y: CGFloat(gy) * step, width: 1.2, height: 1.2)
                        context.fill(Path(ellipseIn: r), with: .color(Color.white.opacity(0.045)))
                    }
                    gy += 1
                }
                gx += 1
            }
        }
        .blendMode(.overlay)
        .opacity(0.42)
    }

    private var heroComposition: some View {
        ZStack {
            // Emerald wash behind the card cluster — anchors the “proof art” in the scene.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            MoveMarkTheme.Colors.primary.opacity(0.22),
                            MoveMarkTheme.Colors.primary.opacity(0.08),
                            MoveMarkTheme.Colors.primary.opacity(0.02),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 190
                    )
                )
                .frame(width: 340, height: 300)
                .blur(radius: 44)
                .offset(x: 8, y: 36)

            reportSilhouette
                .offset(x: -8, y: 18)

            proofTrailConnector
                .frame(width: 310, height: 240)
                .offset(x: 14, y: 34)

            ZStack {
                mainEvidenceCard
                    .rotationEffect(.degrees(-2))
                    .frame(maxWidth: .infinity, alignment: .leading)

                accentDisputeCard
                    .offset(x: 83, y: 97)

                vaultSeal
                    .offset(x: 138, y: 32)
            }
        }
        .frame(height: 372)
        .scaleEffect(0.95)
        .offset(x: 12)
    }

    private var reportSilhouette: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.018))
            .frame(width: 248, height: 300)
            .overlay(
                VStack(alignment: .leading, spacing: 10) {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 7, height: 7)
                    reportLine(width: 0.72)
                    reportLine(width: 0.86)
                    reportLine(width: 0.64)
                    reportLine(width: 0.78)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.045), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            .rotationEffect(.degrees(-7))
            .opacity(0.7)
    }

    private func reportLine(width: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(width: proxy.size.width * width, height: 3)
        }
        .frame(height: 3)
    }

    private var proofTrailConnector: some View {
        ZStack {
            // Soft bloom to suggest connected proof flow.
            Path { path in
                path.move(to: CGPoint(x: 68, y: 150))
                path.addCurve(
                    to: CGPoint(x: 250, y: 104),
                    control1: CGPoint(x: 122, y: 118),
                    control2: CGPoint(x: 194, y: 134)
                )
            }
            .stroke(
                MoveMarkTheme.Colors.primary.opacity(0.3),
                style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
            )
            .blur(radius: 6)

            Path { path in
                path.move(to: CGPoint(x: 68, y: 150))
                path.addCurve(
                    to: CGPoint(x: 250, y: 104),
                    control1: CGPoint(x: 122, y: 118),
                    control2: CGPoint(x: 194, y: 134)
                )
            }
            .trim(from: 0, to: heroRevealed ? 1 : 0)
            .stroke(
                LinearGradient(
                    colors: [
                        MoveMarkTheme.Colors.accent.opacity(0.9),
                        MoveMarkTheme.Colors.primary.opacity(0.95)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
            )
            .animation(.easeOut(duration: 0.6).delay(0.2), value: heroRevealed)
        }
    }

    private var vaultSeal: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("LOCKED")
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.9)
        }
        .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.92))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.58))
                .overlay(
                    Capsule()
                        .stroke(MoveMarkTheme.Colors.primary.opacity(0.3), lineWidth: 0.8)
                )
        )
        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.25), radius: 8, y: 3)
    }

    private var mainEvidenceCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 22/255, green: 21/255, blue: 20/255))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.38), radius: 46, y: 22)
                .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.06), radius: 28, y: 10)

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Image("welcome-kitchen-main")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 146)
                        .clipped()

                    LinearGradient(
                        colors: [
                            .black.opacity(0.18),
                            .clear,
                            .black.opacity(0.58),
                            .black.opacity(0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    HStack {
                        chip("KITCHEN · MOVE-IN", filled: true)

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "camera.metering.center.weighted")
                                .font(MoveMarkTheme.Typography.caption)
                            Text("MM-0414-KT")
                                .font(MoveMarkTheme.Typography.caption)
                        }
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.58))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .frame(height: 146)
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

                    HStack(alignment: .center) {
                        Text("Apr 14, 2025 · 5:42 PM")
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
        .frame(width: 262)
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

            Text("Deposit at risk")
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
        .frame(width: 212)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(red: 18/255, green: 17/255, blue: 16/255).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.32), radius: 36, y: 18)
        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.05), radius: 20, y: 8)
        .rotationEffect(.degrees(2.4))
    }

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    .frame(width: 40, height: 2)
                    .clipShape(Capsule())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Protect your deposit.")
                        .font(MoveMarkTheme.Typography.hero)
                        .tracking(-1.2)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("Prove your case.")
                        .font(MoveMarkTheme.Typography.hero)
                        .tracking(-1.2)
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                }
                .padding(.top, 12)
            }
            .padding(.bottom, 12)

            Text("Document every room, receipt, and issue before your deposit is questioned.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 20)

            welcomeVaultCTA

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text("Already have an account?")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))

                Button {
                    MMHaptics.soft()
                    authInitialMode = .signIn
                    showAuth = true
                } label: {
                    Text("Sign in")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.96))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
        }
    }

    private var welcomeVaultCTA: some View {
        Button {
            MMHaptics.soft()
            authInitialMode = .signUp
            showAuth = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MoveMarkTheme.Colors.primary)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.06),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .padding(1)
                    .mask(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )

                Text("Start your vault")
                    .font(MoveMarkTheme.Typography.button)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.28), radius: 16, y: 8)
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(WelcomeCTAPressStyle())
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

private struct WelcomeCTAPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
    }
}
