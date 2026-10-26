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
        MMSheetScaffold(title: "Edit rental") {
            Text("Changes are saved to this rental. Rooms and evidence are unchanged.")
                .mmFont(15)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)

            fieldSection("Rental") {
                MMField(title: "Nickname or label", placeholder: "e.g. Downtown Condo or 123 Main St", text: $name)
            }
            fieldSection("Address") {
                MMField(title: "Street address", placeholder: "123 Main St", text: $addressLine1, contentType: .streetAddressLine1)
                MMField(title: "Unit", placeholder: "Optional", text: $unit, contentType: .streetAddressLine2)
                MMField(title: "City", placeholder: "San Francisco", text: $city, contentType: .addressCity)
                MMField(title: "Province / state", placeholder: "CA", text: $region, contentType: .addressState)
                MMField(title: "Postal / ZIP code", placeholder: "94102", text: $postalCode,
                        contentType: .postalCode, autocapitalization: .characters)
            }
            MMGroup(title: "Move-in & lease") {
                dateRow("Move-in date", $moveInDate)
                MMRowDivider()
                dateRow("Lease start", $leaseStartDate)
                MMRowDivider()
                dateRow("Lease end", $leaseEndDate)
            }
            .padding(.top, 26)
            fieldSection("Landlord") {
                MMField(title: "Name", placeholder: "Property manager or landlord", text: $landlordName, contentType: .name)
                MMField(title: "Email", placeholder: "Optional", text: $landlordEmail, keyboard: .emailAddress,
                        contentType: .emailAddress, autocapitalization: .never)
                MMField(title: "Phone", placeholder: "Optional", text: $landlordPhone, keyboard: .phonePad,
                        contentType: .telephoneNumber)
            }
            fieldSection("Deposit & rent") {
                MMField(title: "Deposit amount", placeholder: "e.g. 1500", text: $depositAmount, keyboard: .decimalPad)
                MMField(title: "Monthly rent", placeholder: "Optional", text: $rentAmount, keyboard: .decimalPad)
            }
            MMGroup(title: "Country") {
                Picker("Country", selection: $selectedCountryOption) {
                    ForEach(supportedCountries + ["Other"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(MMInk.text)
                .mmFont(16)
                .padding(.horizontal, 16)
                .frame(minHeight: MMMetrics.rowHeight)
            }
            .padding(.top, 26)
            if selectedCountryOption == "Other" {
                MMField(title: "Country code", placeholder: "e.g. FR, DE", text: $customCountry, autocapitalization: .characters)
                    .padding(.top, 12)
            }

            if !errorMessage.isEmpty {
                MMNotice(message: errorMessage).padding(.top, 22)
            }
            MMPrimaryButton(title: "Save changes", isLoading: isLoading,
                            isDisabled: input.validationError != nil || isLoading) { submit() }
                .padding(.top, 26)
        }
    }

    private func fieldSection<Fields: View>(_ title: String, @ViewBuilder _ fields: () -> Fields) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .mmFont(12, .medium)
                .tracking(0.3)
                .foregroundStyle(MMInk.secondary)
                .accessibilityAddTraits(.isHeader)
            fields()
        }
        .padding(.top, 26)
    }

    private func dateRow(_ title: String, _ date: Binding<Date>) -> some View {
        DatePicker(title, selection: date, displayedComponents: .date)
            .mmFont(16)
            .foregroundStyle(MMInk.text)
            .tint(MMInk.text)
            .padding(.horizontal, 16)
            .frame(minHeight: MMMetrics.rowHeight)
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
