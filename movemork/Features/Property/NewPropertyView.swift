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
    @State private var moveInDate: Date
    @State private var leaseStartDate: Date
    @State private var leaseEndDate: Date
    @State private var landlordName = ""
    @State private var landlordEmail = ""
    @State private var landlordPhone = ""
    @State private var depositAmount = ""
    @State private var rentAmount = ""

    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var confirmDiscard = false

    /// Set when this sheet owns its Cancel (and asks before dropping what was entered). The presenter's own
    /// Cancel, if it adds one instead, closes without asking.
    private let onCancel: (() -> Void)?
    /// The dates as the form opened, to tell whether anything was entered.
    private let openedDates: [Date]

    init(onCancel: (() -> Void)? = nil) {
        self.init(today: Date(), onCancel: onCancel)
    }

    /// `today` is a snapshot seam: the form as it opens on a fixed day, so the default dates don't drift.
    init(today: Date, onCancel: (() -> Void)? = nil) {
        let leaseEnd = Calendar.current.date(byAdding: .year, value: 1, to: today) ?? today
        _moveInDate = State(initialValue: today)
        _leaseStartDate = State(initialValue: today)
        _leaseEndDate = State(initialValue: leaseEnd)
        openedDates = [today, today, leaseEnd]
        self.onCancel = onCancel
    }

    /// Anything entered that closing the sheet would lose.
    private var hasChanges: Bool {
        let typed = [name, addressLine1, unit, city, region, postalCode, customCountry,
                     landlordName, landlordEmail, landlordPhone, depositAmount, rentAmount]
        return typed.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || selectedCountryOption != "CA"
            || [moveInDate, leaseStartDate, leaseEndDate] != openedDates
    }

    private var detailsIssue: String? {
        RentalFormFields.detailsIssue(email: landlordEmail, deposit: depositAmount, rent: rentAmount)
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
            } else if let leaseError = input.leaseDatesError {
                MMNotice(message: leaseError).padding(.top, 22)
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
        .toolbar {
            if let onCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        MMDiscardChanges.cancel(hasChanges: hasChanges, isConfirming: $confirmDiscard, dismiss: onCancel)
                    }
                    .disabled(isLoading)
                }
            }
        }
        .mmDiscardChangesGuard(hasChanges: hasChanges, isBusy: isLoading, isConfirming: $confirmDiscard,
                               onDiscard: { if let onCancel { onCancel() } else { dismiss() } })
    }

    private var isSubmitDisabled: Bool {
        input.validationError != nil || detailsIssue != nil || isLoading
    }

    private func submit() {
        #if DEBUG
        print("🟢 Submit tapped")
        print("🧪 validationError: \(input.validationError ?? "nil")")
        print("👤 userId: \(sessionManager.userId?.uuidString ?? "nil")")
        #endif

        if let msg = input.validationError ?? detailsIssue {
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
