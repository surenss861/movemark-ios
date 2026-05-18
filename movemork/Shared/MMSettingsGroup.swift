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
                .font(.system(size: 13, weight: .semibold))
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
        .mmProofCardSurface(.neutral, cornerRadius: 14)
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

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
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
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.7))
        case .external:
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.7))
        case .value(let text):
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .lineLimit(1)
        case .pill(let text, let tone):
            MMPill(text: text, tone: tone)
        }
    }
}

struct MMSettingsDivider: View {
    var body: some View {
        Divider()
            .background(Color.white.opacity(0.06))
            .padding(.leading, 14)
    }
}
