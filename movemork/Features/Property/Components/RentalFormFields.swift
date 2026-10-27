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

    private var optionalVisible: Bool { showOptional ?? optionalStartsExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section("Address") {
                MMField(title: "Street address", placeholder: "88 Harbour St", text: $addressLine1,
                        contentType: .streetAddressLine1, autocapitalization: .words, accessibilityID: "Street address")
                MMField(title: "Unit", placeholder: "Optional", text: $unit, contentType: .streetAddressLine2,
                        autocapitalization: .words)
                MMField(title: "City", placeholder: "Toronto", text: $city, contentType: .addressCity,
                        autocapitalization: .words)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        MMField(title: "Province / state", placeholder: "ON", text: $region, contentType: .addressState,
                                autocapitalization: .characters)
                        MMField(title: "Postal / ZIP code", placeholder: "M5J 2N8", text: $postalCode,
                                contentType: .postalCode, autocapitalization: .characters)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        MMField(title: "Province / state", placeholder: "ON", text: $region, contentType: .addressState,
                                autocapitalization: .characters)
                        MMField(title: "Postal / ZIP code", placeholder: "M5J 2N8", text: $postalCode,
                                contentType: .postalCode, autocapitalization: .characters)
                    }
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
                    MMField(title: "Country code", placeholder: "e.g. FR, DE", text: $customCountry, autocapitalization: .characters)
                }
            }

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
                    MMField(title: "Rental name", placeholder: "Leave blank to use the street address", text: $name)
                }
                section("Landlord") {
                    MMField(title: "Name", placeholder: "Landlord or property manager", text: $landlordName, contentType: .name)
                    MMField(title: "Email", placeholder: "Optional", text: $landlordEmail, keyboard: .emailAddress,
                            contentType: .emailAddress, autocapitalization: .never)
                    MMField(title: "Phone", placeholder: "Optional", text: $landlordPhone, keyboard: .phonePad,
                            contentType: .telephoneNumber)
                }
                section("Deposit & rent") {
                    MMField(title: "Deposit amount", placeholder: "e.g. 1500", text: $depositAmount, keyboard: .decimalPad)
                    MMField(title: "Monthly rent", placeholder: "Optional", text: $rentAmount, keyboard: .decimalPad)
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
