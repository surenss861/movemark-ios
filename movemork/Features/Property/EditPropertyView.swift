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

    /// The rental had lease dates when the sheet opened (an epoch end means none was entered).
    private let hadLease: Bool
    /// The form as it opened, to tell whether anything was edited.
    private let initialFieldValues: [String]
    private let initialDateValues: [Date]

    init(property: PropertyRecord) {
        self.property = property
        // A title that is just the street address stays blank here, so it keeps following the address if the
        // street is edited (blank saves as the address).
        let title = property.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let street = property.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = title == street ? "" : property.title
        let city = RentalLocation.meaningful(property.city) ?? ""
        let region = RentalLocation.meaningful(property.provinceState) ?? ""
        let postalCode = RentalLocation.meaningful(property.postalCode) ?? ""
        let storedCountry = property.country.isEmpty ? "CA" : property.country
        let fixedOptions = ["CA", "US", "GB", "AU", "NZ"]
        let countryOption = fixedOptions.contains(storedCountry) ? storedCountry : "Other"
        let customCountry = fixedOptions.contains(storedCountry) ? "" : storedCountry
        let hadLease = property.leaseEndDate.timeIntervalSince1970 > 0 || property.leaseStartDate != nil
        let leaseStart = property.leaseStartDate ?? property.moveInDate
        // No lease yet: the pickers still need a value, but it's only saved if the renter sets one.
        let leaseEnd = property.leaseEndDate.timeIntervalSince1970 > 0
            ? property.leaseEndDate
            : (Calendar.current.date(byAdding: .year, value: 1, to: leaseStart) ?? leaseStart)
        let deposit = property.depositAmount.filter { $0.isNumber || $0 == "." }
        let rent = property.rentAmount.filter { $0.isNumber || $0 == "." }

        _name = State(initialValue: name)
        _addressLine1 = State(initialValue: property.addressLine1)
        _unit = State(initialValue: property.addressLine2)
        _city = State(initialValue: city)
        _region = State(initialValue: region)
        _postalCode = State(initialValue: postalCode)
        _selectedCountryOption = State(initialValue: countryOption)
        _customCountry = State(initialValue: customCountry)
        _moveInDate = State(initialValue: property.moveInDate)
        _leaseStartDate = State(initialValue: leaseStart)
        _leaseEndDate = State(initialValue: leaseEnd)
        _landlordName = State(initialValue: property.landlordName)
        _landlordEmail = State(initialValue: property.landlordEmail)
        _landlordPhone = State(initialValue: property.landlordPhone)
        _depositAmount = State(initialValue: deposit)
        _rentAmount = State(initialValue: rent)

        self.hadLease = hadLease
        initialFieldValues = [name, property.addressLine1, property.addressLine2, city, region, postalCode,
                              countryOption, customCountry, property.landlordName, property.landlordEmail,
                              property.landlordPhone, deposit, rent]
        initialDateValues = [property.moveInDate, leaseStart, leaseEnd]
    }

    private var fieldValues: [String] {
        [name, addressLine1, unit, city, region, postalCode, selectedCountryOption, customCountry,
         landlordName, landlordEmail, landlordPhone, depositAmount, rentAmount]
    }

    private var dateValues: [Date] { [moveInDate, leaseStartDate, leaseEndDate] }

    /// Unsaved edits: the sheet can't be swiped away while there are any.
    private var hasChanges: Bool {
        fieldValues != initialFieldValues || dateValues != initialDateValues
    }

    /// Lease dates are saved when the rental had a lease or the renter changed either date.
    private var savesLease: Bool {
        hadLease || leaseStartDate != initialDateValues[1] || leaseEndDate != initialDateValues[2]
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
            leaseStartDate: savesLease ? leaseStartDate : nil,
            leaseEndDate: savesLease ? leaseEndDate : nil,
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
            } else if let leaseError = input.leaseDatesError {
                MMNotice(message: leaseError).padding(.top, 22)
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
        .interactiveDismissDisabled(hasChanges)
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
