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
            return "Unlock more property vaults"
        case .unlimitedExports:
            return "Unlock unlimited exports"
        case .disputePacket:
            return "Unlock case-ready dispute tools"
        case .moveOutExport:
            return "Unlock move-out protection"
        }
    }

    var subheadline: String {
        switch self {
        case .extraProperty:
            return "Track multiple rentals, keep every proof trail organized, and manage more than one property."
        case .unlimitedExports:
            return "Export more than your included free report and keep generating professional proof PDFs when you need them."
        case .disputePacket:
            return "Build a stronger renter case with dispute-ready proof, structured evidence, and premium export tools."
        case .moveOutExport:
            return "Move-out is where deposit disputes usually happen. Upgrade to export your move-out proof and protect your side."
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
