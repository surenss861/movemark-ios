//
//  MMPill.swift
//  movemork
//
//  MoveMark — Stamped status chips on dark emerald.
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
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.3)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral: return MoveMarkTheme.Colors.textSecondary
        case .accent: return MoveMarkTheme.Colors.proofMint
        case .success: return MoveMarkTheme.Colors.limeAccent
        case .warning: return MoveMarkTheme.Colors.semanticWarning
        case .danger: return MoveMarkTheme.Colors.semanticDanger
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral: return MoveMarkTheme.Colors.surface.opacity(0.9)
        case .accent: return MoveMarkTheme.Colors.primary.opacity(0.18)
        case .success: return MoveMarkTheme.Colors.primary.opacity(0.2)
        case .warning: return MoveMarkTheme.Colors.semanticWarning.opacity(0.16)
        case .danger: return MoveMarkTheme.Colors.semanticDanger.opacity(0.14)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral: return MoveMarkTheme.Colors.subtleStroke
        case .accent: return MoveMarkTheme.Colors.primary.opacity(0.45)
        case .success: return MoveMarkTheme.Colors.proofMint.opacity(0.5)
        case .warning: return MoveMarkTheme.Colors.semanticWarning.opacity(0.5)
        case .danger: return MoveMarkTheme.Colors.semanticDanger.opacity(0.45)
        }
    }
}
