//
//  MMButton.swift
//  movemork
//
//  MoveMark — Chunky primary (green), secondary (white), quiet actions.
//

import SwiftUI

struct MMButton: View {
    enum Kind {
        case primary
        case secondary
        case quiet
    }

    enum Size {
        case hero
        case standard
        case compact

        var height: CGFloat {
            switch self {
            case .hero: return 58
            case .standard: return 48
            case .compact: return 38
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .hero: return 18
            case .standard: return 16
            case .compact: return 12
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .hero: return 16
            case .standard: return 14
            case .compact: return 12
            }
        }

        var font: Font {
            switch self {
            case .hero:
                return MoveMarkTheme.Typography.button
            case .standard:
                return MoveMarkTheme.Typography.subheadlineMedium
            case .compact:
                return .system(size: 13.5, weight: .semibold)
            }
        }
    }

    let title: String
    let action: () -> Void

    var kind: Kind = .primary
    var size: Size = .hero
    var isDisabled: Bool = false
    var expandsToFillWidth: Bool = true

    init(
        title: String,
        action: @escaping () -> Void,
        isSecondary: Bool = false,
        isDisabled: Bool = false
    ) {
        self.title = title
        self.action = action
        self.kind = isSecondary ? .secondary : .primary
        self.size = .hero
        self.isDisabled = isDisabled
        self.expandsToFillWidth = true
    }

    init(
        title: String,
        action: @escaping () -> Void,
        kind: Kind = .primary,
        size: Size = .hero,
        isDisabled: Bool = false,
        expandsToFillWidth: Bool = true
    ) {
        self.title = title
        self.action = action
        self.kind = kind
        self.size = size
        self.isDisabled = isDisabled
        self.expandsToFillWidth = expandsToFillWidth
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(size.font)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: expandsToFillWidth ? .infinity : nil)
                .frame(height: size.height)
                .padding(.horizontal, expandsToFillWidth ? 0 : size.horizontalPadding)
                .background(backgroundView)
                .clipShape(
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                )
        }
        .buttonStyle(MMButtonPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1.0)
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            return MoveMarkTheme.Colors.textOnPrimary
        case .secondary, .quiet:
            return MoveMarkTheme.Colors.textDarkGreen
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch kind {
        case .primary:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(MoveMarkTheme.Colors.primary)

        case .secondary:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(MoveMarkTheme.Colors.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 1.2)
                )

        case .quiet:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(MoveMarkTheme.Colors.mint.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.7), lineWidth: 0.8)
                )
        }
    }
}

private struct MMButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.14), value: configuration.isPressed)
    }
}
