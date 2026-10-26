//
//  EditPropertyView.swift
//  movemork
//
//  MoveMark — edit rental identity and lease metadata without touching proof.
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

    private let supportedCountries = ["CA", "US", "GB", "AU", "NZ"]

    init(property: PropertyRecord) {
        self.property = property
        _name = State(initialValue: property.title.isEmpty ? property.addressLine1 : property.title)
        _addressLine1 = State(initialValue: property.addressLine1)
        _unit = State(initialValue: property.addressLine2)
        _city = State(initialValue: RentalLocation.meaningful(property.city) ?? "")
        _region = State(initialValue: RentalLocation.meaningful(property.provinceState) ?? "")
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
                VStack(alignment: .leading, spacing: MoveMarkTheme.Spacing.sectionGap) {
                    header

                    formGroup("Rental") {
                        MMTextField(
                            title: "Rental name",
                            placeholder: "My Apartment",
                            text: $name
                        )
                        MMTextField(title: "Street address", placeholder: "123 Main St", text: $addressLine1)
                        MMTextField(title: "Unit / apartment", placeholder: "Optional", text: $unit)
                        MMTextField(title: "City", placeholder: "Toronto", text: $city)
                        MMTextField(title: "Province / state", placeholder: "ON", text: $region)
                        MMTextField(title: "Postal / ZIP code", placeholder: "M5V 1A1", text: $postalCode)

                        Picker("Country", selection: $selectedCountryOption) {
                            ForEach(supportedCountries + ["Other"], id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(MoveMarkTheme.Colors.textPrimary)

                        if selectedCountryOption == "Other" {
                            MMTextField(
                                title: "Country code",
                                placeholder: "e.g. FR, DE",
                                text: $customCountry
                            )
                            .textInputAutocapitalization(.characters)
                        }
                    }

                    formGroup("Dates") {
                        dateRow("Move-in date", selection: $moveInDate)
                        dateRow("Lease start", selection: $leaseStartDate)
                        dateRow("Lease end", selection: $leaseEndDate)
                    }

                    formGroup("Landlord") {
                        MMTextField(
                            title: "Name",
                            placeholder: "Property manager or landlord",
                            text: $landlordName
                        )
                        MMTextField(
                            title: "Email",
                            placeholder: "Optional",
                            text: $landlordEmail,
                            keyboardType: .emailAddress
                        )
                        MMTextField(
                            title: "Phone",
                            placeholder: "Optional",
                            text: $landlordPhone,
                            keyboardType: .phonePad
                        )
                    }

                    formGroup("Money") {
                        MMTextField(
                            title: "Deposit amount",
                            placeholder: "e.g. 1500",
                            text: $depositAmount,
                            keyboardType: .decimalPad
                        )
                        MMTextField(
                            title: "Rent amount",
                            placeholder: "Optional",
                            text: $rentAmount,
                            keyboardType: .decimalPad
                        )
                    }

                    if !errorMessage.isEmpty {
                        MMErrorBanner(message: errorMessage)
                    }

                    ZStack {
                        MMButton(
                            title: "Save changes",
                            action: submit,
                            kind: .primary,
                            isDisabled: input.validationError != nil || isLoading
                        )
                        .opacity(isLoading ? 0.6 : 1)

                        if isLoading {
                            ProgressView()
                                .tint(MoveMarkTheme.Colors.textOnPrimary)
                        }
                    }
                }
                .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                .padding(.top, 22)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("Edit rental")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RENTAL DETAILS")
                .font(MoveMarkTheme.Typography.sectionLabel)
                .tracking(0.9)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

            Text("Update the rental, not the proof.")
                .font(MoveMarkTheme.Typography.pageTitle)
                .tracking(-0.8)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Rooms, evidence, maintenance cases, and reports stay unchanged when you edit these details.")
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func formGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MMSectionLabel(title)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.card, style: .continuous)
                    .fill(MoveMarkTheme.Surface.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.card, style: .continuous)
                    .stroke(MoveMarkTheme.Stroke.normal, lineWidth: 1)
            )
        }
    }

    private func dateRow(_ title: String, selection: Binding<Date>) -> some View {
        DatePicker(title, selection: selection, displayedComponents: .date)
            .font(MoveMarkTheme.Typography.subheadlineMedium)
            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            .tint(MoveMarkTheme.Colors.primary)
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

        guard !isLoading else { return }

        errorMessage = ""
        isLoading = true

        Task { @MainActor in
            defer { isLoading = false }

            do {
                try await propertyStore.updateProperty(propertyId: property.id, input: input, userId: userId)
                MMHaptics.success()
                dismiss()
            } catch {
                errorMessage = MoveMarkFlowMessage.propertyUpdateFailed(error)
                MMHaptics.error()
            }
        }
    }
}
