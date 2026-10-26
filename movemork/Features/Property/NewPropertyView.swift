//
//  NewPropertyView.swift
//  movemork
//
//  MoveMark — create one rental record, then add rooms and proof.
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

    private let supportedCountries = ["CA", "US", "GB", "AU", "NZ"]

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
                            title: "Create rental",
                            action: submit,
                            kind: .primary,
                            isDisabled: isSubmitDisabled
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
        .navigationTitle("Add rental")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NEW RENTAL")
                .font(MoveMarkTheme.Typography.sectionLabel)
                .tracking(0.9)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

            Text("Start the record here.")
                .font(MoveMarkTheme.Typography.pageTitle)
                .tracking(-0.8)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("This identifies the rental that your rooms, photos, records, maintenance cases, and reports belong to.")
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

    private var isSubmitDisabled: Bool {
        input.validationError != nil || isLoading
    }

    private func submit() {
        if let msg = input.validationError {
            errorMessage = msg
            return
        }

        guard let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.notSignedInPropertyForm
            return
        }

        guard !isLoading else { return }

        errorMessage = ""
        isLoading = true

        Task { @MainActor in
            defer { isLoading = false }

            do {
                try await propertyStore.createProperty(input: input, userId: userId)
                MMHaptics.success()
                dismiss()
            } catch {
                errorMessage = MoveMarkFlowMessage.propertyCreateFailed(error)
                MMHaptics.error()
            }
        }
    }
}
