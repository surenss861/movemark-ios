//
//  ProofStatusBadge.swift
//  movemork
//
//  The one status-badge system. Every chip in the app is one of four tones with the same
//  shape, padding, type and stroke — `MMPill` renders through this too.
//

import SwiftUI

enum ProofStatusTone {
    /// Ready / Active / Added.
    case success
    /// Needed / Missing.
    case warning
    /// Failed. Used sparingly — it is the only red in the app.
    case danger
    /// Next / new.
    case info
    /// Draft / In progress / counts.
    case neutral
}

struct ProofStatusBadge: View {
    let text: String
    var tone: ProofStatusTone = .success

    var body: some View {
        Text(text)
            .font(MoveMarkTheme.Typography.tinyEmphasis)
            .tracking(0.2)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(background))
            .overlay(Capsule().stroke(border, lineWidth: 0.75))
            .fixedSize()
    }

    private var tint: Color {
        switch tone {
        case .success: MoveMarkTheme.Colors.primary
        case .warning: MoveMarkTheme.Colors.semanticWarning
        case .danger: MoveMarkTheme.Colors.semanticDanger
        case .info: MoveMarkTheme.Colors.semanticInfo
        case .neutral: MoveMarkTheme.Colors.textSecondary
        }
    }

    private var background: Color {
        tone == .neutral ? MoveMarkTheme.Surface.interactive : tint.opacity(0.14)
    }

    private var foreground: Color {
        tone == .neutral ? MoveMarkTheme.Colors.textSecondary : tint
    }

    private var border: Color {
        tone == .neutral ? MoveMarkTheme.Stroke.normal : tint.opacity(0.36)
    }
}
