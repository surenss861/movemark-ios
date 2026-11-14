//
//  FirstRunSetupTitleTests.swift
//  movemorkTests
//
//  First-run setup names the rental from its address (no nickname field): "88 Harbour St, Unit 1204".
//

import Foundation
import Testing
@testable import MoveMark

@MainActor
struct FirstRunSetupTitleTests {
    @Test func streetAloneIsTheTitle() {
        #expect(FirstRunPropertySetupView.title(street: " 88 Harbour St ", unit: "") == "88 Harbour St")
    }

    @Test func bareUnitGetsAPrefix() {
        #expect(FirstRunPropertySetupView.title(street: "88 Harbour St", unit: "1204") == "88 Harbour St, Unit 1204")
    }

    @Test func prefixedUnitIsKept() {
        #expect(FirstRunPropertySetupView.title(street: "88 Harbour St", unit: "Apt 3") == "88 Harbour St, Apt 3")
        #expect(FirstRunPropertySetupView.title(street: "88 Harbour St", unit: "#3") == "88 Harbour St, #3")
    }

    @Test func derivedTitleSatisfiesPropertyValidation() {
        let input = CreatePropertyInput(
            name: FirstRunPropertySetupView.title(street: "88 Harbour St", unit: ""), addressLine1: "88 Harbour St",
            unit: "", city: "Toronto", region: "", postalCode: "", country: "CA", moveInDate: .now,
            leaseStartDate: .now, leaseEndDate: .now, landlordName: "", landlordEmail: "", landlordPhone: "",
            depositAmount: "", rentAmount: "")
        #expect(input.validationError == nil)
        #expect(RentalLocation.line(city: input.city, province: input.region) == "Toronto")
    }
}
