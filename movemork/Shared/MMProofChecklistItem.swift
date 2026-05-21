//
//  MMProofChecklistItem.swift
//  movemork
//

import Foundation

struct MMProofChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let state: State

    enum State {
        case complete
        case incomplete
        case locked
    }
}
