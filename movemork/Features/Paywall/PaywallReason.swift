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
            return "Track multiple rentals and keep each proof trail organized."
        case .unlimitedExports:
            return "Make professional proof PDFs whenever you need them."
        case .disputePacket:
            return "Stronger dispute-ready proof and premium export tools."
        case .moveOutExport:
            return "Export move-out proof when deposit risk is real."
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
