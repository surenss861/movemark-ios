//
//  RoomRecord.swift
//  movemork
//
//  MoveMark — Room with move-in and move-out evidence.
//

import Foundation

struct RoomRecord: Identifiable, Codable, Hashable {
    enum ConditionRating: String, Codable, CaseIterable, Hashable {
        /// Worst → best (matches picker order).
        case poor = "Poor"
        /// Stored as `condition_rating` **2** in DB — between poor (1) and fair (3).
        case belowFair = "Below fair"
        case fair = "Fair"
        case good = "Good"
        case excellent = "Excellent"

        /// 1–5 value for `ConditionMeter` and API `condition_rating` (must match `PropertyStore+Mutations` encoding).
        var conditionMeterValue: Int {
            switch self {
            case .excellent: return 5
            case .good: return 4
            case .fair: return 3
            case .belowFair: return 2
            case .poor: return 1
            }
        }
    }

    let id: UUID
    var name: String
    var evidence: [EvidenceRecord]
    var moveOutEvidence: [EvidenceRecord]

    init(
        id: UUID = UUID(),
        name: String,
        evidence: [EvidenceRecord] = [],
        moveOutEvidence: [EvidenceRecord] = []
    ) {
        self.id = id
        self.name = name
        self.evidence = evidence
        self.moveOutEvidence = moveOutEvidence
    }
}
