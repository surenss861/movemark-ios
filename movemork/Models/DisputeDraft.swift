//
//  DisputeDraft.swift
//  movemork
//
//  MoveMark — Dispute packet draft model.
//

import Foundation

struct DisputeDraft: Identifiable, Codable, Hashable {
    enum DisputeType: String, Codable, CaseIterable, Hashable {
        case depositWithheld = "Deposit withheld"
        case cleaningFee = "Cleaning fee"
        case falseDamage = "False damage"
        case other = "Other"
    }

    let id: UUID
    var type: DisputeType
    var summary: String
    var selectedEvidenceCount: Int
    var selectedDocumentCount: Int

    init(
        id: UUID = UUID(),
        type: DisputeType = .depositWithheld,
        summary: String = "",
        selectedEvidenceCount: Int = 0,
        selectedDocumentCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.summary = summary
        self.selectedEvidenceCount = selectedEvidenceCount
        self.selectedDocumentCount = selectedDocumentCount
    }
}
