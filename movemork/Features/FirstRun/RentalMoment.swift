//
//  RentalMoment.swift
//  movemork
//
//  The stage of the rental a renter is documenting — decides whether the first capture is move-in or
//  move-out evidence. Two paths only: first run never routes into reports, damage or disputes.
//

import Foundation

/// Every moment still produces proof the same way (rental → room → capture); the moment decides whether
/// the first capture is recorded as move-out evidence.
enum RentalMoment: String, CaseIterable, Identifiable {
    case justMovedIn
    case movingOut

    var id: String { rawValue }

    // MARK: - Picker option

    var title: String {
        switch self {
        case .justMovedIn: return "Moving into a rental"
        case .movingOut: return "Moving out"
        }
    }

    var blurb: String {
        switch self {
        case .justMovedIn: return "Record how it looks before you unpack."
        case .movingOut: return "Compare how you’re leaving it."
        }
    }

    var iconName: String {
        switch self {
        case .justMovedIn: return "shippingbox"
        case .movingOut: return "key"
        }
    }

    // MARK: - Capture behaviour

    /// Move-out records the first capture as move-out evidence so it lands on the before-and-after side
    /// of the report.
    var capturesMoveOutEvidence: Bool {
        self == .movingOut
    }

    // MARK: - Saved receipt

    var receiptPhaseLabel: String {
        switch self {
        case .justMovedIn: return "Move-in"
        case .movingOut: return "Move-out"
        }
    }

    var receiptDocumentedLabel: String {
        switch self {
        case .justMovedIn: return "Move-in proof started"
        case .movingOut: return "Move-out proof started"
        }
    }
}
