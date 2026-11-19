//
//  RoomRecord.swift
//  movemork
//
//  MoveMark — Room with move-in and move-out evidence.
//

import Foundation

nonisolated struct RoomRecord: Identifiable, Codable, Hashable {
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
    /// Loaded move-in entries, newest first. Large rooms load their newest entries first (snapshot v2); older
    /// ones load on demand, and what is not loaded yet is counted in `moveInUnloaded`.
    var evidence: [EvidenceRecord]
    var moveOutEvidence: [EvidenceRecord]
    /// What the server counted beyond the loaded entries (nil = nothing unloaded). Totals are loaded entries
    /// plus this remainder, so optimistic edits to loaded entries keep the totals right without bookkeeping.
    var moveInUnloaded: StageTotals? = nil
    var moveOutUnloaded: StageTotals? = nil

    nonisolated struct StageTotals: Codable, Hashable {
        var entries = 0
        var photos = 0
        var notedEntries = 0
        var issueTags = 0
        var latestAt: Date? = nil
    }

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

// MARK: - Totals (loaded entries + unloaded remainder)

extension RoomRecord {
    private static func sum(_ entries: [EvidenceRecord], _ rest: StageTotals?) -> StageTotals {
        StageTotals(
            entries: entries.count + (rest?.entries ?? 0),
            photos: entries.reduce(0) { $0 + $1.photoCount } + (rest?.photos ?? 0),
            notedEntries: entries.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
                + (rest?.notedEntries ?? 0),
            issueTags: entries.reduce(0) { $0 + $1.issueTags.count } + (rest?.issueTags ?? 0),
            latestAt: [entries.map(\.createdAt).max(), rest?.latestAt].compactMap { $0 }.max()
        )
    }

    var moveInTotals: StageTotals { Self.sum(evidence, moveInUnloaded) }
    var moveOutTotals: StageTotals { Self.sum(moveOutEvidence, moveOutUnloaded) }

    // Single totals compute only their own field: these run per room, several times per Proof / room-list
    // render, and the full StageTotals also trims every entry's notes (1,500-character notes add up).
    var moveInEntryTotal: Int { evidence.count + (moveInUnloaded?.entries ?? 0) }
    var moveInPhotoTotal: Int { evidence.reduce(0) { $0 + $1.photoCount } + (moveInUnloaded?.photos ?? 0) }
    var moveInIssueTagTotal: Int { evidence.reduce(0) { $0 + $1.issueTags.count } + (moveInUnloaded?.issueTags ?? 0) }
    var moveInLatestAt: Date? { [evidence.map(\.createdAt).max(), moveInUnloaded?.latestAt].compactMap { $0 }.max() }
    var moveOutEntryTotal: Int { moveOutEvidence.count + (moveOutUnloaded?.entries ?? 0) }
    var moveOutPhotoTotal: Int { moveOutEvidence.reduce(0) { $0 + $1.photoCount } + (moveOutUnloaded?.photos ?? 0) }
    var moveOutIssueTagTotal: Int { moveOutEvidence.reduce(0) { $0 + $1.issueTags.count } + (moveOutUnloaded?.issueTags ?? 0) }

    /// Older entries exist that are not loaded yet (load with `PropertyStore.loadOlderEntries`).
    func hasOlderEntries(moveOut: Bool) -> Bool { ((moveOut ? moveOutUnloaded : moveInUnloaded)?.entries ?? 0) > 0 }
}

