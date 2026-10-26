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
        MMScreen(title: moment.setupTitle, subtitle: moment.setupSubtitle) {
            VStack(alignment: .leading, spacing: 14) {
                if requiresOnboarding {
                    field("Your name", placeholder: "Optional", text: $yourName)
                }
                field("Rental name", placeholder: "My apartment", text: $rentalName)
                field("City / location", placeholder: "Optional", text: $city)
            }

            MMGroup {
                DatePicker("Move-in date", selection: $moveInDate, displayedComponents: .date)
                    .mmFont(16)
                    .foregroundStyle(MMInk.text)
                    .tint(MMInk.text)
                    .padding(.horizontal, 16)
                    .frame(minHeight: MMMetrics.rowHeight)
            }
            .padding(.top, 22)

            if !errorMessage.isEmpty {
                MMNotice(message: errorMessage)
                    .padding(.top, 22)
            }

            MMPrimaryButton(title: moment.setupCTA, isLoading: isLoading) { createVault() }
                .padding(.top, 26)
        }
    }

    /// Same input behaviour as before the system pass: no auto-capitalisation, no autocorrect.
    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        MMField(title: title, placeholder: placeholder, text: text, autocapitalization: .never)
            .autocorrectionDisabled()
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
                    city: location,
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

extension FirstRunPropertySetupView {
    /// Snapshot tests only: open with an error already showing. In an extension so the memberwise init
    /// the flow uses stays as it is.
    init(requiresOnboarding: Bool, moment: RentalMoment, previewError: String) {
        self.init(requiresOnboarding: requiresOnboarding, moment: moment, onCreated: { _ in })
        _errorMessage = State(initialValue: previewError)
    }
}
