//
//  RentalMoment.swift
//  movemork
//
//  The rental moment a renter is in — drives first-run framing and capture mode.
//

import Foundation

/// Why the renter opened MoveMark today. Every moment still produces proof the
/// same way (vault → room → capture); the moment tailors framing and decides
/// whether the first capture is recorded as move-out evidence.
enum RentalMoment: String, CaseIterable, Identifiable {
    case justMovedIn
    case foundDamage
    case movingOut
    case needReport
    case depositQuestioned

    var id: String { rawValue }

    // MARK: - Picker card

    var title: String {
        switch self {
        case .justMovedIn: return "I just moved in"
        case .foundDamage: return "I found damage"
        case .movingOut: return "I'm moving out"
        case .needReport: return "I need a report"
        case .depositQuestioned: return "My deposit is being questioned"
        }
    }

    var blurb: String {
        switch self {
        case .justMovedIn: return "Capture rooms before you unpack."
        case .foundDamage: return "Timestamp it before it gets blamed on you."
        case .movingOut: return "Re-capture rooms before you hand back the keys."
        case .needReport: return "Turn room photos into a shareable PDF."
        case .depositQuestioned: return "Document what you can still reach today."
        }
    }

    var iconName: String {
        switch self {
        case .justMovedIn: return "shippingbox"
        case .foundDamage: return "exclamationmark.triangle"
        case .movingOut: return "key"
        case .needReport: return "doc.text"
        case .depositQuestioned: return "shield.lefthalf.filled"
        }
    }

    // MARK: - Vault setup step

    var setupTitle: String {
        switch self {
        case .justMovedIn: return MoveMarkGrowthCopy.firstRunSetupTitle
        case .foundDamage: return "Get it on record."
        case .movingOut: return "Prove how you left it."
        case .needReport: return "Reports start with proof."
        case .depositQuestioned: return "Build your case."
        }
    }

    var setupSubtitle: String {
        switch self {
        case .justMovedIn:
            return MoveMarkGrowthCopy.firstRunSetupSubtitle
        case .foundDamage:
            return "Add this rental, then photograph the damage with a timestamp."
        case .movingOut:
            return "Add this rental, then re-capture each room before you return the keys."
        case .needReport:
            return "Add this rental, then document rooms — your report is built from what you capture."
        case .depositQuestioned:
            return "Add this rental, then capture everything you can still document."
        }
    }

    // MARK: - Room pick step

    var roomTitle: String {
        switch self {
        case .justMovedIn: return MoveMarkGrowthCopy.firstRunRoomTitle
        case .foundDamage: return "Where's the damage?"
        case .movingOut: return "Re-capture one room."
        case .needReport: return "Start with one room."
        case .depositQuestioned: return "Start where it matters."
        }
    }

    var roomSubtitle: String {
        switch self {
        case .justMovedIn:
            return MoveMarkGrowthCopy.firstRunRoomSubtitle
        case .foundDamage:
            return "Pick the room, then shoot it wide and up close."
        case .movingOut:
            return "Match how the room looked when you moved in."
        case .needReport:
            return "Every room you document adds a section to your report."
        case .depositQuestioned:
            return "Pick the room you're being charged for."
        }
    }

    // MARK: - Setup CTA

    var setupCTA: String {
        switch self {
        case .justMovedIn: return "Start move-in proof"
        case .foundDamage: return "Document damage"
        case .movingOut: return "Start move-out proof"
        case .needReport: return "Build report"
        case .depositQuestioned: return "Organize proof"
        }
    }

    // MARK: - Capture behaviour

    /// Move-out moments record the first capture as move-out evidence so it
    /// lands on the before-and-after side of the report.
    var capturesMoveOutEvidence: Bool {
        self == .movingOut
    }

    // MARK: - Saved receipt

    var receiptPhaseLabel: String {
        switch self {
        case .justMovedIn: return "Move-in"
        case .foundDamage: return "Damage"
        case .movingOut: return "Move-out"
        case .needReport: return "Report"
        case .depositQuestioned: return "Deposit"
        }
    }

    var receiptDocumentedLabel: String {
        switch self {
        case .justMovedIn: return "Move-in proof started"
        case .foundDamage: return "Damage saved to your proof"
        case .movingOut: return "Move-out proof started"
        case .needReport: return "Ready to build your report"
        case .depositQuestioned: return "Deposit proof getting organized"
        }
    }
}
