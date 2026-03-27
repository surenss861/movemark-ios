//
//  MMPill.swift
//  movemork
//
//  MoveMark — Status and tag pill component.
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
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
        case .accent: return MoveMarkTheme.Colors.accent
        case .success: return MoveMarkTheme.Colors.primary
        case .warning: return Color.orange.opacity(0.95)
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral: return Color.white.opacity(0.03)
        case .accent: return MoveMarkTheme.Colors.accent.opacity(0.10)
        case .success: return MoveMarkTheme.Colors.primary.opacity(0.10)
        case .warning: return Color.orange.opacity(0.10)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral: return MoveMarkTheme.Colors.panelStroke
        case .accent: return MoveMarkTheme.Colors.accent.opacity(0.30)
        case .success: return MoveMarkTheme.Colors.primary.opacity(0.30)
        case .warning: return Color.orange.opacity(0.30)
        }
    }
}
