//
//  MaintenanceRecord.swift
//  movemork
//
//  MoveMark — Maintenance incident log.
//

import Foundation

struct MaintenanceRecord: Identifiable, Codable, Hashable {
    enum Status: String, Codable, CaseIterable, Hashable {
        case open = "Open"
        case followUp = "Follow-up"
        case resolved = "Resolved"
    }

    let id: UUID
    var title: String
    var category: String
    var details: String
    var status: Status
    var createdAt: Date
    var landlordResponse: String
    var photoCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        details: String,
        status: Status = .open,
        createdAt: Date = Date(),
        landlordResponse: String = "",
        photoCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.details = details
        self.status = status
        self.createdAt = createdAt
        self.landlordResponse = landlordResponse
        self.photoCount = photoCount
    }
}
