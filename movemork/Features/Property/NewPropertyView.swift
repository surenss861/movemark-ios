//
//  NewPropertyView.swift
//  movemork
//
//  MoveMark — Add a rental: form → CreatePropertyInput → store → Neon → Proof.
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
        MMSheetScaffold(title: "Add rental") {
            Text("Your rental's proof — room photos, records, issues and reports — lives here.")
                .mmFont(15)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)

            fieldSection("Rental") {
                MMField(title: "Nickname or address", placeholder: "e.g. 88 Harbour St", text: $name)
            }
            fieldSection("Address") {
                MMField(title: "Street address", placeholder: "123 Main St", text: $addressLine1, contentType: .streetAddressLine1)
                MMField(title: "Unit", placeholder: "Optional", text: $unit, contentType: .streetAddressLine2)
                MMField(title: "City", placeholder: "Toronto", text: $city, contentType: .addressCity)
                MMField(title: "Province / state", placeholder: "ON", text: $region, contentType: .addressState)
                MMField(title: "Postal / ZIP code", placeholder: "M5J 2N8", text: $postalCode,
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
            MMPrimaryButton(title: "Create rental", isLoading: isLoading, isDisabled: isSubmitDisabled) { submit() }
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
