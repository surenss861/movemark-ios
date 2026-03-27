//
//  RoomRecord.swift
//  movemork
//
//  MoveMark — Room with move-in and move-out evidence.
//

import Foundation

struct RoomRecord: Identifiable, Codable, Hashable {
    enum ConditionRating: String, Codable, CaseIterable, Hashable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"

        /// 1–5 value for ConditionMeter (excellent=5, good=4, fair=3, poor=1).
        var conditionMeterValue: Int {
            switch self {
            case .excellent: return 5
            case .good: return 4
            case .fair: return 3
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
