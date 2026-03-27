//
//  MMButton.swift
//  movemork
//
//  MoveMark — Primary, secondary, quiet; hero / standard / compact.
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

    /// Backward compatibility for legacy isSecondary call sites.
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
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.52 : 1.0)
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            return .white
        case .secondary, .quiet:
            return MoveMarkTheme.Colors.textPrimary
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
                .fill(MoveMarkTheme.Colors.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.9), lineWidth: 1)
                )

        case .quiet:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.55), lineWidth: 0.8)
                )
        }
    }
}
