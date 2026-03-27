//
//  ChecklistRepository.swift
//  movemork
//
//  MoveMark — Move-out checklist data access.
//

import Foundation
import Supabase

struct MoveOutChecklistRow: Codable, Identifiable {
    var id: UUID?
    let propertyId: UUID
    let userId: UUID
    var cabinetsClear: Bool
    var appliancesClean: Bool
    var keysReturned: Bool
    var utilitiesCancelled: Bool
    var cleaningReceiptUploaded: Bool
    var forwardingAddressNoted: Bool
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case userId = "user_id"
        case cabinetsClear = "cabinets_clear"
        case appliancesClean = "appliances_clean"
        case keysReturned = "keys_returned"
        case utilitiesCancelled = "utilities_cancelled"
        case cleaningReceiptUploaded = "cleaning_receipt_uploaded"
        case forwardingAddressNoted = "forwarding_address_noted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var completedCount: Int {
        [cabinetsClear, appliancesClean, keysReturned,
         utilitiesCancelled, cleaningReceiptUploaded, forwardingAddressNoted]
            .filter { $0 }.count
    }
}

struct ChecklistRepository {

    func fetchChecklist(propertyId: UUID, userId: UUID) async throws -> MoveOutChecklistRow? {
        let rows: [MoveOutChecklistRow] = try await supabase
            .from("move_out_checklists")
            .select()
            .eq("property_id", value: propertyId)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func upsertChecklist(_ row: MoveOutChecklistRow) async throws {
        try await supabase
            .from("move_out_checklists")
            .upsert(row, onConflict: "property_id,user_id")
            .execute()
    }
}
