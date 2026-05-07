//
//  MMHaptics.swift
//  movemork
//
//  Single source of truth for haptic feedback. Use at meaningful moments only.
//
//  MoveMark is a proof / trust surface — haptics reinforce “locked in” and errors,
//  not gamification. Prefer:
//  - `selection` / `soft` / `light`: navigation, toggles, light affordances
//  - `success`: proof saved, export queued, restore / purchase success
//  - `medium`: sparingly for a heavier physical cue (e.g. alongside a major state change)
//  - `warning` / `error`: incomplete data, failed network or storage, destructive outcomes
//

import UIKit

enum MMHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
    }

    static func soft() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare()
        g.impactOccurred()
    }

    /// Heavier than `light` / `soft`; use rarely so it still reads as “something important happened.”
    static func medium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        g.impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
