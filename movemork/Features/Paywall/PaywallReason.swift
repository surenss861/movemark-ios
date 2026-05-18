//
//  PaywallReason.swift
//  movemork
//
//  MoveMark — Reusable paywall entry reasons.
//

import Foundation

enum PaywallReason: Equatable {
    case extraProperty
    case unlimitedExports
    case disputePacket
    case moveOutExport

    /// Primary paywall headline (shared across entry points).
    var headline: String {
        switch self {
        case .extraProperty:
            return "Protect more than one rental"
        case .unlimitedExports:
            return "Make more move-in reports"
        case .disputePacket:
            return "Build a dispute-ready packet"
        case .moveOutExport:
            return "Document move-out proof"
        }
    }

    /// Context line under the shared Pro value prop.
    var subheadline: String {
        switch self {
        case .extraProperty:
            return "Add another rental vault when you move."
        case .unlimitedExports:
            return "You’ve used your free move-in report on this account."
        case .disputePacket:
            return "Organize proof into a stronger dispute workflow."
        case .moveOutExport:
            return "Re-capture rooms and export move-out reports with Pro."
        }
    }

    var ctaTitle: String {
        "Start Pro"
    }
}
