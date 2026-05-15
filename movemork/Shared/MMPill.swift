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
        case danger
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
        case .accent: return MoveMarkTheme.Colors.textDarkGreen
        case .success: return MoveMarkTheme.Colors.textDarkGreen
        case .warning: return MoveMarkTheme.Colors.textDeepGreen
        case .danger: return MoveMarkTheme.Colors.semanticDanger
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral: return MoveMarkTheme.Colors.mint.opacity(0.45)
        case .accent: return MoveMarkTheme.Colors.primary.opacity(0.14)
        case .success: return MoveMarkTheme.Colors.primary.opacity(0.16)
        case .warning: return MoveMarkTheme.Colors.semanticWarning.opacity(0.22)
        case .danger: return MoveMarkTheme.Colors.semanticDanger.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral: return MoveMarkTheme.Colors.panelStroke
        case .accent: return MoveMarkTheme.Colors.primary.opacity(0.35)
        case .success: return MoveMarkTheme.Colors.primary.opacity(0.35)
        case .warning: return MoveMarkTheme.Colors.semanticWarning.opacity(0.45)
        case .danger: return MoveMarkTheme.Colors.semanticDanger.opacity(0.35)
        }
    }
}
