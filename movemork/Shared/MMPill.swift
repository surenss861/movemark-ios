//
//  MMPill.swift
//  movemork
//
//  Legacy name for a status chip. Renders through `ProofStatusBadge` so there is one
//  badge system; `accent` maps to info.
//

import SwiftUI

struct MMPill: View {
    let text: String
    var tone: Tone = .neutral

    enum Tone {
        case neutral
        case accent
        case success
        case warning
        case danger
    }

    var body: some View {
        ProofStatusBadge(text: text, tone: badgeTone)
    }

    private var badgeTone: ProofStatusTone {
        switch tone {
        case .neutral: .neutral
        case .accent: .info
        case .success: .success
        case .warning: .warning
        case .danger: .danger
        }
    }
}
