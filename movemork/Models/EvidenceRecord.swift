//
//  EvidenceRecord.swift
//  movemork
//
//  MoveMark — Evidence entry for rooms.
//

import Foundation

/// Reference to a row in `evidence_files` (storage path under `inspection-media`).
struct EvidencePhoto: Identifiable, Codable, Hashable {
    let id: UUID
    let filePath: String
}

struct EvidenceRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var notes: String
    var issueTags: [String]
    var condition: RoomRecord.ConditionRating
    var createdAt: Date
    /// After hydration, matches `photos.count`. Before upload completes in memory-only flows, may reflect count without `photos` filled.
    var photoCount: Int
    /// File paths from `evidence_files` for thumbnails and previews after reload.
    var photos: [EvidencePhoto]
    var stage: Stage

    enum Stage: String, Codable, CaseIterable, Hashable {
        case moveIn = "Move-in"
        case maintenance = "Maintenance"
        case moveOut = "Move-out"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, issueTags, condition, createdAt, photoCount, photos, stage
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String,
        issueTags: [String],
        condition: RoomRecord.ConditionRating,
        createdAt: Date = Date(),
        photoCount: Int,
        photos: [EvidencePhoto] = [],
        stage: Stage
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.issueTags = issueTags
        self.condition = condition
        self.createdAt = createdAt
        self.photos = photos
        self.photoCount = photos.isEmpty ? photoCount : photos.count
        self.stage = stage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decode(String.self, forKey: .notes)
        issueTags = try c.decode([String].self, forKey: .issueTags)
        condition = try c.decode(RoomRecord.ConditionRating.self, forKey: .condition)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        photos = try c.decodeIfPresent([EvidencePhoto].self, forKey: .photos) ?? []
        let decodedCount = try c.decode(Int.self, forKey: .photoCount)
        photoCount = photos.isEmpty ? decodedCount : photos.count
        stage = try c.decode(Stage.self, forKey: .stage)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(notes, forKey: .notes)
        try c.encode(issueTags, forKey: .issueTags)
        try c.encode(condition, forKey: .condition)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(photoCount, forKey: .photoCount)
        try c.encode(photos, forKey: .photos)
        try c.encode(stage, forKey: .stage)
    }
}
