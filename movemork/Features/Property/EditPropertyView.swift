//
//  EditPropertyView.swift
//  movemork
//
//  MoveMark — Edit active property. Sheet from Vault; save to DB and refresh.
//

import SwiftUI

struct EditPropertyView: View {
    let property: PropertyRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var name: String
    @State private var addressLine1: String
    @State private var unit: String
    @State private var city: String
    @State private var region: String
    @State private var postalCode: String
    @State private var selectedCountryOption: String
    @State private var customCountry: String
    @State private var moveInDate: Date
    @State private var leaseStartDate: Date
    @State private var leaseEndDate: Date
    @State private var landlordName: String
    @State private var landlordEmail: String
    @State private var landlordPhone: String
    @State private var depositAmount: String
    @State private var rentAmount: String

    @State private var errorMessage = ""
    @State private var isLoading = false

    init(property: PropertyRecord) {
        self.property = property
        _name = State(initialValue: property.title.isEmpty ? property.addressLine1 : property.title)
        _addressLine1 = State(initialValue: property.addressLine1)
        _unit = State(initialValue: property.addressLine2)
        _city = State(initialValue: property.city)
        _region = State(initialValue: property.provinceState)
        _postalCode = State(initialValue: property.postalCode)
        let storedCountry = property.country.isEmpty ? "CA" : property.country
        let fixedOptions = ["CA", "US", "GB", "AU", "NZ"]
        if fixedOptions.contains(storedCountry) {
            _selectedCountryOption = State(initialValue: storedCountry)
            _customCountry = State(initialValue: "")
        } else {
            _selectedCountryOption = State(initialValue: "Other")
            _customCountry = State(initialValue: storedCountry)
        }
        _moveInDate = State(initialValue: property.moveInDate)
        _leaseStartDate = State(initialValue: property.leaseStartDate ?? property.moveInDate)
        _leaseEndDate = State(initialValue: property.leaseEndDate)
        _landlordName = State(initialValue: property.landlordName)
        _landlordEmail = State(initialValue: property.landlordEmail)
        _landlordPhone = State(initialValue: property.landlordPhone)
        _depositAmount = State(initialValue: property.depositAmount.filter { $0.isNumber || $0 == "." })
        _rentAmount = State(initialValue: property.rentAmount.filter { $0.isNumber || $0 == "." })
    }

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
                    MMCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Edit property")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            Text("Changes are saved to this property. Rooms and evidence are unchanged.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        }
                    }

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

                    MMCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Financials")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            MMTextField(title: "Deposit amount", placeholder: "e.g. 1500", text: $depositAmount, keyboardType: .decimalPad)
                            MMTextField(title: "Rent amount (optional)", placeholder: "e.g. 2200", text: $rentAmount, keyboardType: .decimalPad)
                        }
                    }

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

                    ZStack {
                        MMButton(
                            title: "Save changes",
                            action: { submit() },
                            isDisabled: input.validationError != nil || isLoading
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

    private func submit() {
        if let msg = input.validationError {
            errorMessage = msg
            return
        }
        guard let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.notSignedInShort
            return
        }
        if isLoading { return }

        errorMessage = ""
        isLoading = true

        Task { @MainActor in
            defer { isLoading = false }
            do {
                try await propertyStore.updateProperty(propertyId: property.id, input: input, userId: userId)
                dismiss()
            } catch {
                errorMessage = MoveMarkFlowMessage.propertyUpdateFailed(error)
            }
        }
    }
}
