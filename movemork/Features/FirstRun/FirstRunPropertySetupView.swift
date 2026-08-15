//
//  FirstRunPropertySetupView.swift
//  movemork
//
//  Minimal rental setup — framed by the selected rental moment.
//

import SwiftUI

struct FirstRunPropertySetupView: View {
    let requiresOnboarding: Bool
    var moment: RentalMoment = .justMovedIn
    let onCreated: (UUID) -> Void
    var onOnboardingNameCaptured: ((String) -> Void)? = nil

    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var yourName = ""
    @State private var rentalName = "My apartment"
    @State private var city = ""
    @State private var moveInDate = Date()
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                MMRenterHeader(
                    title: moment.setupTitle,
                    subtitle: moment.setupSubtitle
                )

                VStack(alignment: .leading, spacing: 12) {
                    if requiresOnboarding {
                        MMTextField(
                            title: "Your name",
                            placeholder: "Optional",
                            text: $yourName,
                            density: .authCompact
                        )
                    }

                    MMTextField(
                        title: "Rental name",
                        placeholder: "My apartment",
                        text: $rentalName,
                        density: .authCompact
                    )

                    MMTextField(
                        title: "City / location",
                        placeholder: "Optional",
                        text: $city,
                        density: .authCompact
                    )

                    DatePicker("Move-in date", selection: $moveInDate, displayedComponents: .date)
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .tint(MoveMarkTheme.Colors.primary)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                    }

                    ZStack {
                        MMButton(
                            title: moment.setupCTA,
                            action: { createVault() },
                            kind: .primary,
                            size: .auth,
                            isDisabled: isLoading
                        )
                        .opacity(isLoading ? 0.6 : 1)

                        if isLoading {
                            ProgressView()
                                .tint(MoveMarkTheme.Colors.primary)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(MoveMarkTheme.Colors.card.opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.5), lineWidth: 0.75)
                )
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .mmProofShellBackground(heroFocus: false, ctaBloom: false)
    }

    private func createVault() {
        guard !isLoading else { return }
        guard let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.signInRequired
            return
        }

        let label = rentalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            errorMessage = "Enter a name for this rental."
            return
        }

        let location = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = location.isEmpty ? label : location

        isLoading = true
        errorMessage = ""

        Task { @MainActor in
            defer { isLoading = false }
            do {
                if requiresOnboarding {
                    let name = yourName.trimmingCharacters(in: .whitespacesAndNewlines)
                    onOnboardingNameCaptured?(name.isEmpty ? "Renter" : name)
                }

                let input = CreatePropertyInput(
                    name: label,
                    addressLine1: address,
                    unit: "",
                    city: location.isEmpty ? "Unknown" : location,
                    region: "",
                    postalCode: "",
                    country: "CA",
                    moveInDate: moveInDate,
                    leaseStartDate: moveInDate,
                    leaseEndDate: Calendar.current.date(byAdding: .year, value: 1, to: moveInDate) ?? moveInDate,
                    landlordName: "",
                    landlordEmail: "",
                    landlordPhone: "",
                    depositAmount: "",
                    rentAmount: ""
                )

                try await propertyStore.createProperty(input: input, userId: userId)

                guard let propertyId = propertyStore.activePropertyId else {
                    errorMessage = "Couldn’t open your new vault. Try again."
                    return
                }

                MMHaptics.success()
                MoveMarkAnalytics.track(.proofVaultCreated)
                onCreated(propertyId)
            } catch {
                errorMessage = MoveMarkFlowMessage.propertyCreateFailed(error)
                MMHaptics.error()
            }
        }
    }
}
