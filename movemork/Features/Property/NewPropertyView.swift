//
//  NewPropertyView.swift
//  movemork
//
//  MoveMark — Add your rental: address first, dates, optional details → CreatePropertyInput → store → Neon.
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
        MMSheetScaffold(title: "Add your rental") {
            Text("Start a dated record of the condition you moved into.")
                .mmFont(15)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)

            RentalFormFields(
                name: $name, addressLine1: $addressLine1, unit: $unit, city: $city, region: $region,
                postalCode: $postalCode, selectedCountryOption: $selectedCountryOption, customCountry: $customCountry,
                moveInDate: $moveInDate, leaseStartDate: $leaseStartDate, leaseEndDate: $leaseEndDate,
                landlordName: $landlordName, landlordEmail: $landlordEmail, landlordPhone: $landlordPhone,
                depositAmount: $depositAmount, rentAmount: $rentAmount, optionalStartsExpanded: false
            )

            if !errorMessage.isEmpty {
                MMNotice(message: errorMessage).padding(.top, 22)
            }
            MMPrimaryButton(title: "Create rental record", isLoading: isLoading, isDisabled: isSubmitDisabled) { submit() }
                .padding(.top, 26)
            Text("Next, you'll add rooms and photograph each one.")
                .mmFont(12.5)
                .foregroundStyle(MMInk.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
        }
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

extension NewPropertyView {
    /// Snapshot tests only: the form as it opens on a fixed day, so the default dates don't drift.
    init(today: Date) {
        _moveInDate = State(initialValue: today)
        _leaseStartDate = State(initialValue: today)
        _leaseEndDate = State(initialValue: Calendar.current.date(byAdding: .year, value: 1, to: today) ?? today)
    }
}
