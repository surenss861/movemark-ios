//
//  EditPropertyView.swift
//  movemork
//
//  MoveMark — Edit rental: a plain utility form (same fields as setup), Save. Sheet from the rental record.
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
            Text("Rooms, photos and records stay exactly as they are.")
                .mmFont(15)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)

            RentalFormFields(
                name: $name, addressLine1: $addressLine1, unit: $unit, city: $city, region: $region,
                postalCode: $postalCode, selectedCountryOption: $selectedCountryOption, customCountry: $customCountry,
                moveInDate: $moveInDate, leaseStartDate: $leaseStartDate, leaseEndDate: $leaseEndDate,
                landlordName: $landlordName, landlordEmail: $landlordEmail, landlordPhone: $landlordPhone,
                depositAmount: $depositAmount, rentAmount: $rentAmount, optionalStartsExpanded: true
            )

            if !errorMessage.isEmpty {
                MMNotice(message: errorMessage).padding(.top, 22)
            }
            MMPrimaryButton(title: "Save changes", isLoading: isLoading,
                            isDisabled: input.validationError != nil || isLoading) { submit() }
                .padding(.top, 26)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { submit() }
                    .fontWeight(.semibold)
                    .disabled(input.validationError != nil || isLoading)
            }
        }
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
