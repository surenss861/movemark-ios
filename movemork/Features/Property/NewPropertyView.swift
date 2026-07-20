//
//  NewPropertyView.swift
//  movemork
//
//  MoveMark — Add your property. Single flow: form → CreatePropertyInput → store → Supabase → Vault.
//

import SwiftUI

struct NewPropertyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var name = ""
    @State private var addressLine1 = ""
    @State private var unit = ""
    @State private var city = ""
    @State private var region = ""
    @State private var postalCode = ""
    @State private var selectedCountryOption = "CA"
    @State private var customCountry = ""
    @State private var moveInDate = Date()
    @State private var leaseStartDate = Date()
    @State private var leaseEndDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var landlordName = ""
    @State private var landlordEmail = ""
    @State private var landlordPhone = ""
    @State private var depositAmount = ""
    @State private var rentAmount = ""

    @State private var errorMessage = ""
    @State private var isLoading = false

    private var countryValue: String {
        selectedCountryOption == "Other" ? customCountry : selectedCountryOption
    }

    private let supportedCountries = ["CA", "US", "GB", "AU", "NZ"]

    private var input: CreatePropertyInput {
        CreatePropertyInput(
            name: name,
            addressLine1: addressLine1,
            unit: unit,
            city: city,
            region: region,
            postalCode: postalCode,
            country: countryValue,
            moveInDate: moveInDate,
            leaseStartDate: leaseStartDate,
            leaseEndDate: leaseEndDate,
            landlordName: landlordName,
            landlordEmail: landlordEmail,
            landlordPhone: landlordPhone,
            depositAmount: depositAmount,
            rentAmount: rentAmount
        )
    }

    var body: some View {
        ZStack {
            MoveMarkTheme.Colors.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 1. Intro
                    MMCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add your property")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            Text("This is where your proof trail starts. Photos, documents, issues, and exports will live here.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        }
                    }

                    // 2. Property
                    MMCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Property")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            MMTextField(
                                title: "Nickname or label",
                                placeholder: "e.g. Downtown Condo or 123 Main St",
                                text: $name
                            )
                        }
                    }

                    // 3. Address
                    MMCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Address")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            MMTextField(title: "Address line 1", placeholder: "123 Main St", text: $addressLine1)
                            MMTextField(title: "Unit / apartment", placeholder: "Optional", text: $unit)
                            MMTextField(title: "City", placeholder: "San Francisco", text: $city)
                            MMTextField(title: "Province / state", placeholder: "CA", text: $region)
                            MMTextField(title: "Postal / ZIP code", placeholder: "94102", text: $postalCode)
                        }
                    }

                    // 4. Move-in & lease
                    MMCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Move-in & lease")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            DatePicker("Move-in date", selection: $moveInDate, displayedComponents: .date)
                                .colorScheme(.light)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            DatePicker("Lease start", selection: $leaseStartDate, displayedComponents: .date)
                                .colorScheme(.light)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            DatePicker("Lease end", selection: $leaseEndDate, displayedComponents: .date)
                                .colorScheme(.light)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        }
                    }

                    // 5. Landlord
                    MMCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Landlord")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            MMTextField(title: "Name", placeholder: "Property manager or landlord", text: $landlordName)
                            MMTextField(title: "Email", placeholder: "Optional", text: $landlordEmail, keyboardType: .emailAddress)
                            MMTextField(title: "Phone", placeholder: "Optional", text: $landlordPhone, keyboardType: .phonePad)
                        }
                    }

                    // 6. Financials
                    MMCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Financials")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            MMTextField(title: "Deposit amount", placeholder: "e.g. 1500", text: $depositAmount, keyboardType: .decimalPad)
                            MMTextField(title: "Rent amount (optional)", placeholder: "e.g. 2200", text: $rentAmount, keyboardType: .decimalPad)
                        }
                    }

                    // 7. Country (optional)
                    MMCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            Picker("Country", selection: $selectedCountryOption) {
                                ForEach(supportedCountries + ["Other"], id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            if selectedCountryOption == "Other" {
                                MMTextField(title: "Country code", placeholder: "e.g. FR, DE", text: $customCountry)
                                    .textInputAutocapitalization(.characters)
                            }
                        }
                    }

                    if !errorMessage.isEmpty {
                        MMErrorBanner(message: errorMessage)
                    }

                    // CTA
                    ZStack {
                        MMButton(
                            title: "Create property vault",
                            action: { submit() },
                            isDisabled: isSubmitDisabled
                        )
                        .opacity(isLoading ? 0.6 : 1.0)
                        .disabled(isLoading)

                        if isLoading {
                            ProgressView()
                                .tint(MoveMarkTheme.Colors.primary)
                        }
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isSubmitDisabled: Bool {
        input.validationError != nil || isLoading
    }

    private func submit() {
        #if DEBUG
        print("🟢 Submit tapped")
        print("🧪 validationError: \(input.validationError ?? "nil")")
        print("👤 userId: \(sessionManager.userId?.uuidString ?? "nil")")
        #endif

        if let msg = input.validationError {
            errorMessage = msg
            return
        }
        guard let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.notSignedInPropertyForm
            return
        }
        if isLoading { return }

        errorMessage = ""
        isLoading = true

        Task { @MainActor in
            defer { isLoading = false }
            do {
                try await propertyStore.createProperty(input: input, userId: userId)
                dismiss()
            } catch {
                errorMessage = MoveMarkFlowMessage.propertyCreateFailed(error)
            }
        }
    }
}
