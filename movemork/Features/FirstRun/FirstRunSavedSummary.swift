//
//  FirstRunSavedSummary.swift
//  movemork
//

import Foundation

struct FirstRunSavedSummary: Equatable, Hashable {
    let propertyId: UUID
    let roomName: String
    let photoCount: Int
    let issueCount: Int
    let savedAt: Date
}
