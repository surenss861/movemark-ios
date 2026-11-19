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
    /// One-time polished report — for renters who only need protection once.
    case reportPack
    /// Opened from Account (plan row) — no feature was blocked, so no context line.
    case account

    /// Primary paywall headline (shared across entry points).
    var headline: String {
        switch self {
        case .extraProperty:
            return "Protect more than one rental."
        case .unlimitedExports:
            return "Turn proof into more reports."
        case .disputePacket:
            return "Build a dispute-ready packet."
        case .moveOutExport:
            return "Turn move-out proof into a report."
        case .reportPack:
            return "Get one polished report."
        case .account:
            return "Protect the full rental timeline."
        }
    }

    /// Context line under the shared Pro value prop.
    var subheadline: String {
        switch self {
        case .extraProperty:
            return "Free includes 1 proof vault. Add another when you move."
        case .unlimitedExports:
            return "You’ve used your free move-in report on this account."
        case .disputePacket:
            return "Organize photos and docs when your deposit is questioned."
        case .moveOutExport:
            return "The move-out report is part of Pro."
        case .reportPack:
            return "One polished move-in report — no subscription required."
        case .account:
            return "Free keeps the record. Pro turns it into reports and an evidence packet."
        }
    }

    var ctaTitle: String {
        switch self {
        case .reportPack:
            return "Buy Report Pack"
        default:
            return "Start Pro"
        }
    }

    /// Value for the `reason` analytics property.
    var analyticsValue: String {
        switch self {
        case .extraProperty: return "extraProperty"
        case .unlimitedExports: return "unlimitedExports"
        case .disputePacket: return "disputePacket"
        case .moveOutExport: return "moveOutExport"
        case .reportPack: return "reportPack"
        case .account: return "account"
        }
    }

    var prefersReportPackFirst: Bool {
        self == .reportPack || self == .unlimitedExports
    }
}
