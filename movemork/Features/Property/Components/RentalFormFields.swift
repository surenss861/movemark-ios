//
//  RentalFormFields.swift
//  movemork
//
//  @file The rental's fields as one utility form, shared by Add your rental and Edit rental so both read
//        the same as setup: address first (street, unit, city, province, postal code, country), then the
//        dates, then the optional details (name on the record, landlord, deposit and rent). Each screen owns
//        its own state and save; this only lays the fields out.
//  @domain property
//  @see [[NewPropertyView.swift]] [[EditPropertyView.swift]]
//

import SwiftUI

struct RentalFormFields: View {
    @Binding var name: String
    @Binding var addressLine1: String
    @Binding var unit: String
    @Binding var city: String
    @Binding var region: String
    @Binding var postalCode: String
    @Binding var selectedCountryOption: String
    @Binding var customCountry: String
    @Binding var moveInDate: Date
    @Binding var leaseStartDate: Date
    @Binding var leaseEndDate: Date
    @Binding var landlordName: String
    @Binding var landlordEmail: String
    @Binding var landlordPhone: String
    @Binding var depositAmount: String
    @Binding var rentAmount: String
    /// Optional details start folded (Add); Edit shows them.
    var optionalStartsExpanded = true

    static let supportedCountries = ["CA", "US", "GB", "AU", "NZ"]

    @State private var showOptional: Bool? = nil
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case street, unit, city, region, postal, customCountry, name, landlordName, email, phone, deposit, rent
        /// Pads with no return key: the keyboard bar carries Done.
        var usesPad: Bool { self == .phone || self == .deposit || self == .rent }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var optionalVisible: Bool { showOptional ?? optionalStartsExpanded }

    private var regionPostalLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section("Address") {
                MMField(title: "Street address", placeholder: "88 Harbour St", text: $addressLine1,
                        contentType: .streetAddressLine1, autocapitalization: .words, accessibilityID: "Street address",
                        submitLabel: .next, onSubmit: { focus = .unit })
                    .focused($focus, equals: .street)
                MMField(title: "Unit", placeholder: "Optional", text: $unit, contentType: .streetAddressLine2,
                        autocapitalization: .words, submitLabel: .next, onSubmit: { focus = .city })
                    .focused($focus, equals: .unit)
                MMField(title: "City", placeholder: "Toronto", text: $city, contentType: .addressCity,
                        autocapitalization: .words, submitLabel: .next, onSubmit: { focus = .region })
                    .focused($focus, equals: .city)
                // Side by side, except at accessibility sizes: there "Postal / ZIP code" wraps to two lines and
                // drops its field below the province field. (Text fields compress, so ViewThatFits never stacked.)
                regionPostalLayout {
                    regionField
                    postalField
                }
                MMGroup {
                    HStack {
                        Text("Country").mmFont(16).foregroundStyle(MMInk.text)
                        Spacer(minLength: 8)
                        Picker("Country", selection: $selectedCountryOption) {
                            ForEach(Self.supportedCountries + ["Other"], id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(MMInk.text)
                        .mmFont(16)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 6)
                    .frame(minHeight: MMMetrics.rowHeight)
                }
                if selectedCountryOption == "Other" {
                    MMField(title: "Country code", placeholder: "e.g. FR, DE", text: $customCountry,
                            contentType: .countryName, autocapitalization: .characters,
                            submitLabel: .done, onSubmit: { focus = nil })
                        .focused($focus, equals: .customCountry)
                }
            }
            // Street names, cities and postal codes aren't words to correct.
            .autocorrectionDisabled()

            section("Dates") {
                MMGroup(footer: "Your move-in date anchors the record: proof captured around it shows the condition you moved into.") {
                    dateRow("Move-in date", $moveInDate)
                    MMRowDivider()
                    dateRow("Lease start", $leaseStartDate)
                    MMRowDivider()
                    dateRow("Lease end", $leaseEndDate)
                }
            }

            if optionalVisible {
                section("On your record") {
                    MMField(title: "Rental name", placeholder: "Leave blank to use the street address", text: $name,
                            autocapitalization: .words, submitLabel: .next, onSubmit: { focus = .landlordName })
                        .focused($focus, equals: .name)
                }
                section("Landlord") {
                    MMField(title: "Name", placeholder: "Landlord or property manager", text: $landlordName, contentType: .name,
                            autocapitalization: .words, submitLabel: .next, onSubmit: { focus = .email })
                        .autocorrectionDisabled()
                        .focused($focus, equals: .landlordName)
                    VStack(alignment: .leading, spacing: 6) {
                        MMField(title: "Email", placeholder: "Optional", text: $landlordEmail, keyboard: .emailAddress,
                                contentType: .emailAddress, autocapitalization: .never,
                                submitLabel: .next, onSubmit: { focus = .phone })
                            .autocorrectionDisabled()
                            .focused($focus, equals: .email)
                        if focus != .email, Self.emailIssue(landlordEmail) != nil {
                            fieldIssue(Self.emailIssue(landlordEmail))
                        }
                    }
                    MMField(title: "Phone", placeholder: "Optional", text: $landlordPhone, keyboard: .phonePad,
                            contentType: .telephoneNumber)
                        .focused($focus, equals: .phone)
                }
                section("Deposit & rent") {
                    VStack(alignment: .leading, spacing: 6) {
                        MMField(title: "Deposit amount", placeholder: "e.g. 1500", text: $depositAmount, keyboard: .decimalPad)
                            .focused($focus, equals: .deposit)
                        if focus != .deposit { fieldIssue(Self.amountIssue(depositAmount)) }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        MMField(title: "Monthly rent", placeholder: "Optional", text: $rentAmount, keyboard: .decimalPad)
                            .focused($focus, equals: .rent)
                        if focus != .rent { fieldIssue(Self.amountIssue(rentAmount)) }
                    }
                }
            } else {
                MMGroup {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showOptional = true }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(MMInk.secondary).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Name, landlord, deposit and rent").mmFont(15.5).foregroundStyle(MMInk.text)
                                Text("Optional — add now or later").mmFont(13).foregroundStyle(MMInk.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: MMMetrics.rowHeight, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MMLightPressStyle())
                }
                .padding(.top, 26)
            }
        }
        // Phone and amount pads have no return key.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focus?.usesPad == true {
                    Spacer()
                    Button("Done") { focus = nil }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var regionField: some View {
        MMField(title: "Province / state", placeholder: "ON", text: $region, contentType: .addressState,
                autocapitalization: .characters, submitLabel: .next, onSubmit: { focus = .postal })
            .focused($focus, equals: .region)
    }

    private var postalField: some View {
        MMField(title: "Postal / ZIP code", placeholder: "M5J 2N8", text: $postalCode,
                contentType: .postalCode, autocapitalization: .characters,
                submitLabel: selectedCountryOption == "Other" ? .next : .done,
                onSubmit: { focus = selectedCountryOption == "Other" ? .customCountry : nil })
            .focused($focus, equals: .postal)
    }

    /// An inline note under a field that can't be saved as typed (shown once the field is left).
    @ViewBuilder
    private func fieldIssue(_ message: String?) -> some View {
        if let message {
            Text(message)
                .mmFont(12.5)
                .foregroundStyle(MMInk.danger)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 4)
        }
    }

    // MARK: - Inline validation (shared with the screens' Save)

    /// A landlord email that can't be right; blank is fine (it's optional).
    static func emailIssue(_ raw: String) -> String? {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return nil }
        let valid = email.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) != nil
        return valid ? nil : "Check the email address."
    }

    /// An amount that wouldn't save as a number (it would be dropped); blank is fine.
    static func amountIssue(_ raw: String) -> String? {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let value = PropertyStore.parseAmount(raw), value >= 0 else { return "Enter an amount, like 1500." }
        return nil
    }

    /// The first optional detail that can't be saved as typed, or nil.
    static func detailsIssue(email: String, deposit: String, rent: String) -> String? {
        emailIssue(email) ?? amountIssue(deposit) ?? amountIssue(rent)
    }

    private func section<Fields: View>(_ title: String, @ViewBuilder _ fields: () -> Fields) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .mmFont(12, .medium)
                .tracking(0.3)
                .foregroundStyle(MMInk.secondary)
                .padding(.leading, 4)
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
}
