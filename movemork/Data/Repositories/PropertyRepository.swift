//
//  PropertyRepository.swift
//  movemork
//
//  MoveMark — Property and room data access.
//

import Foundation
import Supabase

struct PropertyRow: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var title: String
    var addressLine1: String
    var addressLine2: String?
    var city: String
    var provinceState: String
    var postalCode: String
    var country: String
    var landlordName: String?
    var landlordEmail: String?
    var landlordPhone: String?
    var depositAmount: Double?
    var rentAmount: Double?
    var moveInDate: String?
    var leaseStart: String?
    var leaseEnd: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case addressLine1 = "address_line_1"
        case addressLine2 = "address_line_2"
        case city
        case provinceState = "province_state"
        case postalCode = "postal_code"
        case country
        case landlordName = "landlord_name"
        case landlordEmail = "landlord_email"
        case landlordPhone = "landlord_phone"
        case depositAmount = "deposit_amount"
        case rentAmount = "rent_amount"
        case moveInDate = "move_in_date"
        case leaseStart = "lease_start"
        case leaseEnd = "lease_end"
        case createdAt = "created_at"
    }
}

struct RoomRow: Codable, Identifiable {
    let id: UUID
    let propertyId: UUID
    var name: String
    var sortOrder: Int
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case name
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

struct PropertyRepository {

    func fetchProperties(userId: UUID) async throws -> [PropertyRow] {
        try await supabase
            .from("properties")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    func createProperty(_ row: PropertyRow) async throws -> PropertyRow {
        #if DEBUG
        if let encoded = try? JSONEncoder().encode(row),
           let json = String(data: encoded, encoding: .utf8) {
            print("📦 Property insert payload (JSON): \(json)")
        } else {
            print("📦 Property insert payload: \(row)")
        }
        #endif
        do {
            let created: PropertyRow = try await supabase
                .from("properties")
                .insert(row)
                .select()
                .single()
                .execute()
                .value
            #if DEBUG
            print("✅ Property created: \(created.id)")
            #endif
            return created
        } catch {
            #if DEBUG
            print("❌ createProperty failed: \(error)")
            #endif
            throw error
        }
    }

    func updateProperty(_ row: PropertyRow) async throws {
        struct PropertyPatch: Encodable {
            let title: String
            let addressLine1: String
            let addressLine2: String?
            let city: String
            let provinceState: String
            let postalCode: String
            let country: String
            let landlordName: String?
            let landlordEmail: String?
            let landlordPhone: String?
            let depositAmount: Double?
            let rentAmount: Double?
            let moveInDate: String?
            let leaseStart: String?
            let leaseEnd: String?

            enum CodingKeys: String, CodingKey {
                case title
                case addressLine1 = "address_line_1"
                case addressLine2 = "address_line_2"
                case city
                case provinceState = "province_state"
                case postalCode = "postal_code"
                case country
                case landlordName = "landlord_name"
                case landlordEmail = "landlord_email"
                case landlordPhone = "landlord_phone"
                case depositAmount = "deposit_amount"
                case rentAmount = "rent_amount"
                case moveInDate = "move_in_date"
                case leaseStart = "lease_start"
                case leaseEnd = "lease_end"
            }
        }

        let patch = PropertyPatch(
            title: row.title,
            addressLine1: row.addressLine1,
            addressLine2: row.addressLine2,
            city: row.city,
            provinceState: row.provinceState,
            postalCode: row.postalCode,
            country: row.country,
            landlordName: row.landlordName,
            landlordEmail: row.landlordEmail,
            landlordPhone: row.landlordPhone,
            depositAmount: row.depositAmount,
            rentAmount: row.rentAmount,
            moveInDate: row.moveInDate,
            leaseStart: row.leaseStart,
            leaseEnd: row.leaseEnd
        )

        try await supabase
            .from("properties")
            .update(patch)
            .eq("id", value: row.id)
            .execute()
    }

    func fetchRooms(propertyId: UUID) async throws -> [RoomRow] {
        try await supabase
            .from("rooms")
            .select()
            .eq("property_id", value: propertyId)
            .order("sort_order")
            .execute()
            .value
    }

    func insertRoom(_ row: RoomRow) async throws -> RoomRow {
        try await supabase
            .from("rooms")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }

    func insertDefaultRooms(propertyId: UUID, userId: UUID) async throws {
        let names = [
            "Kitchen", "Living Room", "Primary Bedroom", "Bedroom 2",
            "Bathroom", "Bathroom 2", "Hallway", "Laundry",
            "Storage", "Balcony/Patio"
        ]

        let rooms = names.enumerated().map { index, name in
            RoomRow(
                id: UUID(),
                propertyId: propertyId,
                name: name,
                sortOrder: index
            )
        }

        try await supabase
            .from("rooms")
            .insert(rooms)
            .execute()
    }
}
