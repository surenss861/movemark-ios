//
//  MMButton.swift
//  movemork
//
//  MoveMark — Premium primary CTA with glow and press depth.
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
        /// In-card CTA — slightly shorter than standard.
        case inline
        /// Auth vault CTA — controlled height, no hero glow.
        case auth
        case compact

        var height: CGFloat {
            switch self {
            case .hero: return MoveMarkTheme.Spacing.heroButtonHeight
            case .standard: return 48
            case .inline: return 44
            case .auth: return 56
            case .compact: return 38
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .hero: return 20
            case .standard, .auth, .inline: return 16
            case .compact: return 12
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .hero: return 18
            case .standard, .auth, .inline: return 14
            case .compact: return 12
            }
        }

        var font: Font {
            switch self {
            case .hero:
                return MoveMarkTheme.Typography.button
            case .standard, .auth, .inline:
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
    var showsTrailingArrow: Bool = false

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
        self.showsTrailingArrow = false
    }

    init(
        title: String,
        action: @escaping () -> Void,
        kind: Kind = .primary,
        size: Size = .hero,
        isDisabled: Bool = false,
        expandsToFillWidth: Bool = true,
        showsTrailingArrow: Bool = false
    ) {
        self.title = title
        self.action = action
        self.kind = kind
        self.size = size
        self.isDisabled = isDisabled
        self.expandsToFillWidth = expandsToFillWidth
        self.showsTrailingArrow = showsTrailingArrow
    }

    var body: some View {
        Button(action: action) {
            labelContent
                .frame(maxWidth: expandsToFillWidth ? .infinity : nil)
                .frame(height: size.height)
                .padding(.horizontal, expandsToFillWidth ? size.horizontalPadding : size.horizontalPadding)
                .background(backgroundView)
                .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
                .shadow(
                    color: primaryGlowColor,
                    radius: kind == .primary && size == .hero ? 16 : 0,
                    y: kind == .primary && size == .hero ? 8 : 0
                )
        }
        .buttonStyle(MMButtonPressStyle(kind: kind))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1.0)
    }

    private var labelContent: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(size.font)
                .foregroundStyle(foregroundColor)

            if showsTrailingArrow {
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(foregroundColor.opacity(0.95))
            }
        }
    }

    private var primaryGlowColor: Color {
        guard kind == .primary, !isDisabled else { return .clear }
        switch size {
        case .hero: return MoveMarkTheme.Colors.primary.opacity(0.38)
        case .auth, .standard, .inline: return MoveMarkTheme.Colors.primary.opacity(0.12)
        case .compact: return .clear
        }
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            return MoveMarkTheme.Colors.textOnPrimary
        case .secondary, .quiet:
            return MoveMarkTheme.Colors.textPrimary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch kind {
        case .primary:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [MoveMarkTheme.Colors.primary, MoveMarkTheme.Colors.primary.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.limeAccent.opacity(0.25), lineWidth: 1)
                )

        case .secondary:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(MoveMarkTheme.Colors.cardRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
                )

        case .quiet:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(MoveMarkTheme.Colors.surface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.subtleStroke, lineWidth: 1)
                )
        }
    }
}

private struct MMButtonPressStyle: ButtonStyle {
    let kind: MMButton.Kind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .background {
                if configuration.isPressed, kind == .primary {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MoveMarkTheme.Colors.primaryPressed.opacity(0.35))
                        .blur(radius: 8)
                        .offset(y: 2)
                }
            }
            .animation(reduceMotion ? nil : MMMotion.spring, value: configuration.isPressed)
    }
}
