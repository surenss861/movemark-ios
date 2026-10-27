//
//  FirstRunPropertySetupView.swift
//  movemork
//
//  Establish the rental record: the address and move-in date that appear on every proof record and report.
//  No nickname and no personal name here — the rental is titled from its address, identity lives in Account.
//

import SwiftUI

struct FirstRunPropertySetupView: View {
    var moment: RentalMoment = .justMovedIn
    let onCreated: (UUID) -> Void

    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    private enum Field: Hashable { case street, unit, city, province }
    @FocusState private var focusedField: Field?

    @State private var street = ""
    @State private var unit = ""
    @State private var city = ""
    @State private var province = ""
    @State private var moveInDate = Date()
    @State private var errorMessage = ""
    @State private var isLoading = false

    private var trimmedStreet: String { street.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        MMScreen(
            eyebrow: MoveMarkGrowthCopy.firstRunSetupEyebrow,
            title: MoveMarkGrowthCopy.firstRunSetupTitle,
            subtitle: MoveMarkGrowthCopy.firstRunSetupSubtitle
        ) {
            VStack(alignment: .leading, spacing: 14) {
                MMField(title: "Street address", placeholder: "88 Harbour St", text: $street,
                        contentType: .streetAddressLine1, autocapitalization: .words,
                        accessibilityID: "setup.street", submitLabel: .next,
                        onSubmit: { focusedField = .unit })
                    .focused($focusedField, equals: .street)
                MMField(title: "Unit", placeholder: "Optional", text: $unit,
                        contentType: .streetAddressLine2, autocapitalization: .characters,
                        accessibilityID: "setup.unit", submitLabel: .next,
                        onSubmit: { focusedField = .city })
                    .focused($focusedField, equals: .unit)
                MMField(title: "City", placeholder: "Toronto", text: $city,
                        contentType: .addressCity, autocapitalization: .words,
                        accessibilityID: "setup.city", submitLabel: .next,
                        onSubmit: { focusedField = .province })
                    .focused($focusedField, equals: .city)
                MMField(title: "Province", placeholder: "ON", text: $province,
                        contentType: .addressState, autocapitalization: .characters,
                        accessibilityID: "setup.province", submitLabel: .done,
                        onSubmit: { focusedField = nil })
                    .focused($focusedField, equals: .province)
            }
            .autocorrectionDisabled()

            MMGroup {
                DatePicker("Move-in date", selection: $moveInDate, displayedComponents: .date)
                    .mmFont(16)
                    .foregroundStyle(MMInk.text)
                    .tint(MMInk.text)
                    .padding(.horizontal, 16)
                    .frame(minHeight: MMMetrics.rowHeight)
            }
            .padding(.top, 22)

            if !errorMessage.isEmpty {
                MMNotice(message: errorMessage)
                    .padding(.top, 22)
            }

            MMPrimaryButton(title: MoveMarkGrowthCopy.firstRunSetupCTA, isLoading: isLoading,
                            isDisabled: trimmedStreet.isEmpty) { createRental() }
                .accessibilityIdentifier("setup.create")
                .padding(.top, 26)
        }
    }

    /// "88 Harbour St, Unit 1204" — the rental's title when there is no nickname.
    static func title(street: String, unit: String) -> String {
        let s = street.trimmingCharacters(in: .whitespacesAndNewlines)
        let u = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return s }
        let hasPrefix = ["unit", "apt", "suite", "#"].contains { u.lowercased().hasPrefix($0) }
        return "\(s), \(hasPrefix ? u : "Unit \(u)")"
    }

    private func createRental() {
        guard !isLoading else { return }
        guard let userId = sessionManager.userId else {
            errorMessage = MoveMarkFlowMessage.signInRequired
            return
        }
        guard !trimmedStreet.isEmpty else {
            errorMessage = "Enter the street address."
            return
        }

        focusedField = nil
        isLoading = true
        errorMessage = ""

        Task { @MainActor in
            defer { isLoading = false }
            do {
                let input = CreatePropertyInput(
                    name: Self.title(street: street, unit: unit),
                    addressLine1: trimmedStreet,
                    unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
                    city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                    region: province.trimmingCharacters(in: .whitespacesAndNewlines),
                    postalCode: "",
                    country: "CA",
                    moveInDate: moveInDate,
                    leaseStartDate: moveInDate,
                    leaseEndDate: Calendar.current.date(byAdding: .year, value: 1, to: moveInDate) ?? moveInDate,
                    landlordName: "",
                    landlordEmail: "",
                    landlordPhone: "",
                    depositAmount: "",
                    rentAmount: ""
                )

                try await propertyStore.createProperty(input: input, userId: userId)

                guard let propertyId = propertyStore.activePropertyId else {
                    errorMessage = "Couldn’t open your rental record. Try again."
                    return
                }

                MMHaptics.success()
                MoveMarkAnalytics.track(.proofVaultCreated)
                onCreated(propertyId)
            } catch {
                errorMessage = MoveMarkFlowMessage.propertyCreateFailed(error)
                MMHaptics.error()
            }
        }
    }
}

extension FirstRunPropertySetupView {
    /// Snapshot tests only: open filled in and/or with an error showing. In an extension so the memberwise
    /// init the flow uses stays as it is.
    init(previewStreet: String = "", previewUnit: String = "", previewCity: String = "", previewProvince: String = "",
         previewError: String = "") {
        self.init(onCreated: { _ in })
        _street = State(initialValue: previewStreet)
        _unit = State(initialValue: previewUnit)
        _city = State(initialValue: previewCity)
        _province = State(initialValue: previewProvince)
        _errorMessage = State(initialValue: previewError)
    }
}
