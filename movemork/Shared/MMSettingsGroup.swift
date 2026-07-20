//
//  MMSettingsGroup.swift
//  movemork
//
//  Quiet iOS Settings–style grouped rows for Account.
//

import SwiftUI

struct MMSettingsSectionHeader: View {
    let title: String
    var footer: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MoveMarkTheme.Typography.footnoteEmphasis)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .textCase(.uppercase)
                .padding(.leading, 2)

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 2)
            }
        }
    }
}

struct MMSettingsGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(MoveMarkTheme.Colors.evidenceCard)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MMSettingsRow: View {
    enum Accessory {
        case none
        case chevron
        case external
        case value(String)
        case pill(String, MMPill.Tone)
    }

    let title: String
    var subtitle: String? = nil
    var accessory: Accessory = .chevron
    var isDisabled: Bool = false
    let action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(MMSettingsRowPressStyle(reduceMotion: reduceMotion))
                .disabled(isDisabled)
            } else {
                rowContent
            }
        }
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .font(MoveMarkTheme.Typography.bodySmallEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(MoveMarkTheme.Typography.footnoteRegular)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 8)

            accessoryView
        }
        .padding(.horizontal, 14)
        .padding(.vertical, subtitle == nil ? 12 : 11)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .chevron:
            Image(systemName: "chevron.right")
                .font(MoveMarkTheme.Typography.captionEmphasis)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.7))
        case .external:
            Image(systemName: "arrow.up.right")
                .font(MoveMarkTheme.Typography.tinyEmphasis)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.7))
        case .value(let text):
            Text(text)
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .lineLimit(1)
        case .pill(let text, let tone):
            MMPill(text: text, tone: tone)
        }
    }
}

private struct MMSettingsRowPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : MMMotion.spring, value: configuration.isPressed)
    }
}

struct MMSettingsDivider: View {
    var body: some View {
        Divider()
            .background(Color.white.opacity(0.06))
            .padding(.leading, 14)
    }
}
