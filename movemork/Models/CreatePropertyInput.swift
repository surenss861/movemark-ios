//
//  CreatePropertyInput.swift
//  movemork
//
//  MoveMark — Single contract for property creation (UI → store → repository → Supabase).
//

import Foundation

/// Full-field input for creating a property vault. Maps to the insert DTO.
struct CreatePropertyInput {
    /// Nickname or label, e.g. "Downtown Condo" or "123 Main St". Used as `title` in DB.
    var name: String
    var addressLine1: String
    /// Unit / apartment (stored as address_line_2).
    var unit: String
    var city: String
    var region: String
    var postalCode: String
    var country: String
    var moveInDate: Date
    /// Lease start (often same as move-in). Stored as lease_start.
    var leaseStartDate: Date
    /// Lease end. Stored as lease_end.
    var leaseEndDate: Date
    /// Optional landlord / property manager name.
    var landlordName: String
    var landlordEmail: String
    var landlordPhone: String
    /// Deposit amount as entered (e.g. "1500"). Parsed to Double for DB.
    var depositAmount: String
    /// Rent amount as entered (optional). Parsed to Double for DB.
    var rentAmount: String

    /// Title for DB: name if non-empty, else address line 1.
    var titleValue: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = addressLine1.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? a : n
    }

    /// Validation: need at least address line 1 and a non-empty title (name or address).
    var validationError: String? {
        let a = addressLine1.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return "Enter the property address." }
        if titleValue.isEmpty { return "Enter a property name or address." }
        return nil
    }
}
