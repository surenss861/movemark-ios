//
//  EvidenceRecord.swift
//  movemork
//
//  MoveMark — Evidence entry for rooms.
//

import Foundation

/// Reference to a row in `evidence_files` (storage path under `inspection-media`).
nonisolated struct EvidencePhoto: Identifiable, Codable, Hashable {
    let id: UUID
    let filePath: String
    /// Small (~320px) JPEG path for grid/list thumbnails; `nil` until re-captured (fall back to `filePath`).
    var thumbnailPath: String? = nil
    /// The row's `created_at` exactly as the server sent it — the keyset cursor for the next photo page
    /// (a parsed `Date` loses the microseconds the ordering depends on).
    var serverCreatedAt: String? = nil
}

nonisolated struct EvidenceRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var notes: String
    var issueTags: [String]
    var condition: RoomRecord.ConditionRating
    var createdAt: Date
    /// The entry's true number of photos. `photos` may hold only the first ones (snapshot v2 loads a bounded
    /// number per entry; the rest load on demand), so never derive the count from `photos`.
    var photoCount: Int
    /// File paths from `evidence_files` for thumbnails and previews after reload.
    var photos: [EvidencePhoto]
    var stage: Stage
    /// `created_at` exactly as the server sent it — the keyset cursor for loading older entries.
    var serverCreatedAt: String? = nil

    enum Stage: String, Codable, CaseIterable, Hashable {
        case moveIn = "Move-in"
        case maintenance = "Maintenance"
        case moveOut = "Move-out"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, issueTags, condition, createdAt, photoCount, photos, stage, serverCreatedAt
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
        self.photoCount = max(photoCount, photos.count)
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
        photoCount = max(decodedCount, photos.count)
        stage = try c.decode(Stage.self, forKey: .stage)
        serverCreatedAt = try c.decodeIfPresent(String.self, forKey: .serverCreatedAt)
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
        try c.encodeIfPresent(serverCreatedAt, forKey: .serverCreatedAt)
    }
}
