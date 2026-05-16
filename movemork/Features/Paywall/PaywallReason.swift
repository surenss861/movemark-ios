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

    var headline: String {
        switch self {
        case .extraProperty:
            return "More deposit case vaults"
        case .unlimitedExports:
            return "Unlimited case file reports"
        case .disputePacket:
            return "Dispute packet & case tools"
        case .moveOutExport:
            return "Move-out case exports"
        }
    }

    var subheadline: String {
        switch self {
        case .extraProperty:
            return "Add another deposit case file when you change rentals."
        case .unlimitedExports:
            return "Generate reports from your case file whenever you need them."
        case .disputePacket:
            return "Dispute-ready exports and tools built from the same proof vault."
        case .moveOutExport:
            return "Lock in move-out evidence while deposit risk is on the table."
        }
    }

    var ctaTitle: String {
        switch self {
        case .extraProperty:
            return "Upgrade to Pro"
        case .unlimitedExports:
            return "Get Pro Exports"
        case .disputePacket:
            return "Unlock Case Builder"
        case .moveOutExport:
            return "Unlock Move-out Exports"
        }
    }
}
