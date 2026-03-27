//
//  EvidenceRecord.swift
//  movemork
//
//  MoveMark — Evidence entry for rooms.
//

import Foundation

struct EvidenceRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var notes: String
    var issueTags: [String]
    var condition: RoomRecord.ConditionRating
    var createdAt: Date
    var photoCount: Int
    var stage: Stage

    enum Stage: String, Codable, CaseIterable, Hashable {
        case moveIn = "Move-in"
        case maintenance = "Maintenance"
        case moveOut = "Move-out"
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String,
        issueTags: [String],
        condition: RoomRecord.ConditionRating,
        createdAt: Date = Date(),
        photoCount: Int,
        stage: Stage
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.issueTags = issueTags
        self.condition = condition
        self.createdAt = createdAt
        self.photoCount = photoCount
        self.stage = stage
    }
}
