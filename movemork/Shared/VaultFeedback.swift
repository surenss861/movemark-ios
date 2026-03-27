//
//  VaultFeedback.swift
//  movemork
//
//  Lightweight workflow feedback events and presentation model.
//

import Foundation

enum VaultFeedbackEvent: Equatable {
    case roomCompleted(roomName: String)
    case documentUploaded(documentName: String)
    case readinessImproved(oldScore: Int, newScore: Int)
    case exportsUnlocked
}

struct VaultFeedbackMessage: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?

    static func from(_ event: VaultFeedbackEvent) -> VaultFeedbackMessage {
        switch event {
        case .roomCompleted(let roomName):
            return VaultFeedbackMessage(
                title: "\(roomName) documented",
                subtitle: "The queue is moving forward."
            )

        case .documentUploaded(let documentName):
            return VaultFeedbackMessage(
                title: "\(documentName) uploaded",
                subtitle: "Supporting records are getting stronger."
            )

        case .readinessImproved(let oldScore, let newScore):
            return VaultFeedbackMessage(
                title: "Readiness improved",
                subtitle: "\(oldScore)% → \(newScore)%"
            )

        case .exportsUnlocked:
            return VaultFeedbackMessage(
                title: "Exports are ready",
                subtitle: "You can now generate reports and packets."
            )
        }
    }
}
