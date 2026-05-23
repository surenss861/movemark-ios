//
//  ProofStatusBadge.swift
//  movemork
//

import SwiftUI

enum ProofStatusTone {
    case success
    case warning
    case danger
    case neutral
}

struct ProofStatusBadge: View {
    let text: String
    var tone: ProofStatusTone = .success

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(background))
            .overlay(
                Capsule()
                    .stroke(border, lineWidth: tone == .neutral ? 0 : 0.85)
            )
    }

    private var background: Color {
        switch tone {
        case .success: MoveMarkTheme.Colors.primary.opacity(0.16)
        case .warning: MoveMarkTheme.Colors.semanticWarning.opacity(0.14)
        case .danger: MoveMarkTheme.Colors.semanticDanger.opacity(0.14)
        case .neutral: MoveMarkTheme.Colors.fieldFill.opacity(0.85)
        }
    }

    private var foreground: Color {
        switch tone {
        case .success: MoveMarkTheme.Colors.primary.opacity(0.92)
        case .warning: MoveMarkTheme.Colors.semanticWarning
        case .danger: MoveMarkTheme.Colors.semanticDanger
        case .neutral: MoveMarkTheme.Colors.textSecondary
        }
    }

    private var border: Color {
        switch tone {
        case .success: MoveMarkTheme.Colors.primary.opacity(0.48)
        case .warning: MoveMarkTheme.Colors.semanticWarning.opacity(0.45)
        case .danger: MoveMarkTheme.Colors.semanticDanger.opacity(0.45)
        case .neutral: .clear
        }
    }
}
