//
//  WelcomeSocialActions.swift
//  movemork
//
//  MoveMark — the "or continue with" block on Welcome. Shown only when `SocialSignInConfig.isEnabled`
//  (Debug + probe URL), so Release builds never show a button that can't sign anyone in.
//
//  Apple's button is Apple's own control (`ASAuthorizationAppleIDButton`, white on the dark welcome).
//  Google's button follows Google's light-theme spec. Its "G" mark comes with the GoogleSignIn SDK
//  (pending), so until then it is text-only. That is acceptable only because the block is
//  Debug-and-probe-only.
//

import AuthenticationServices
import SwiftUI

struct WelcomeSocialActions: View {
    let busyProvider: SocialProvider?
    let onSelect: (SocialProvider) -> Void

    var body: some View {
        VStack(spacing: 10) {
            divider

            ForEach(SocialProvider.iOSOrder, id: \.self) { provider in
                button(for: provider)
                    .disabled(busyProvider != nil)
                    .opacity(busyProvider != nil && busyProvider != provider ? 0.55 : 1)
                    .overlay {
                        if busyProvider == provider {
                            Capsule().fill(.black.opacity(0.35))
                            ProgressView().tint(.white)
                        }
                    }
                    .accessibilityIdentifier("welcome.social.\(provider.rawValue)")
            }
        }
    }

    private var divider: some View {
        HStack(spacing: 10) {
            line
            Text("or continue with")
                .mmFont(12.5)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize()
            line
        }
        .accessibilityHidden(true)
    }

    private var line: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
    }

    @ViewBuilder
    private func button(for provider: SocialProvider) -> some View {
        switch provider {
        case .apple:
            AppleIDButton { onSelect(.apple) }
                .frame(maxWidth: .infinity)
                .frame(height: MMMetrics.ctaHeight)
                .clipShape(Capsule())
                .accessibilityLabel(provider.buttonTitle)
        case .google:
            Button { onSelect(.google) } label: {
                Text(provider.buttonTitle)
                    // Matches the optical size Apple's control picks at this height, so the pair reads as one set.
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color(red: 0.122, green: 0.122, blue: 0.122))
                    .frame(maxWidth: .infinity)
                    .frame(height: MMMetrics.ctaHeight)
                    .background(Color.white, in: Capsule())
                    // Inset, so the 1pt outline never spills past the fill and gets clipped into stray edges.
                    .overlay(Capsule().strokeBorder(Color(red: 0.455, green: 0.467, blue: 0.459), lineWidth: 1))
                    // Nothing paints past the rounded ends (the snapshot showed hairlines at the extremes).
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(MMLightPressStyle())
            .accessibilityLabel(provider.buttonTitle)
        }
    }
}

/// Apple's own "Continue with Apple" control. The tap goes to our provider (nonce, error handling);
/// the button itself only supplies the branding Apple requires.
private struct AppleIDButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(authorizationButtonType: .continue, authorizationButtonStyle: .white)
        button.cornerRadius = MMMetrics.ctaHeight / 2
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
