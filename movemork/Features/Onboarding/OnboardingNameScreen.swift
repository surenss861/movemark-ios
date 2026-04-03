//
//  OnboardingNameScreen.swift
//  movemork
//
//  MoveMark — Minimal name onboarding after sign-up.
//

import SwiftUI

struct OnboardingNameScreen: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var firstName = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            backgroundAtmosphere

            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                Rectangle()
                    .fill(MoveMarkTheme.Colors.accent)
                    .frame(width: 38, height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("What should we call you?")
                        .font(MoveMarkTheme.Typography.screenTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("Your proof trail starts with a clean record.")
                        .font(MoveMarkTheme.Typography.body)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }

                MMCard(tone: .elevated, padding: 22, spacing: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        MMTextField(
                            title: "Full name",
                            placeholder: "Enter your full name",
                            text: $firstName
                        )

                        if !errorMessage.isEmpty {
                            MMErrorBanner(message: errorMessage)
                        }

                        ZStack {
                            MMButton(
                                title: "Continue",
                                action: { submitOnboarding() },
                                kind: .primary,
                                size: .hero,
                                isDisabled: isLoading
                            )
                            .opacity(isLoading ? 0.6 : 1.0)

                            if isLoading {
                                ProgressView()
                                    .tint(MoveMarkTheme.Colors.primary)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.vertical, 24)
        }
    }

    private var backgroundAtmosphere: some View {
        ZStack {
            MoveMarkTheme.Colors.background.ignoresSafeArea()

            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.primary.opacity(0.05),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 60,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.accent.opacity(0.035),
                    .clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 260
            )
        }
    }

    private func submitOnboarding() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = ""

        Task { @MainActor in
            defer { isLoading = false }
            do {
                try await sessionManager.completeOnboarding(firstName: firstName)
            } catch {
                errorMessage = MoveMarkFlowMessage.onboardingProfileSaveFailed(error)
            }
        }
    }
}
