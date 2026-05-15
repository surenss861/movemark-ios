//
//  MMEditorialHeader.swift
//  movemork
//
//  Standard header: eyebrow, title, subtitle, green rule.
//

import SwiftUI

struct MMEditorialHeader: View {
    enum Surface {
        case light
        case darkShell
    }

    let eyebrow: String
    let title: String
    let subtitle: String
    var titleFont: Font = .system(size: 36, weight: .bold)
    var surface: Surface = .darkShell

    private var titleColor: Color {
        surface == .darkShell ? MoveMarkTheme.Colors.textOnDark : MoveMarkTheme.Colors.textOnLight
    }

    private var subtitleColor: Color {
        surface == .darkShell ? MoveMarkTheme.Colors.textOnDarkMuted : MoveMarkTheme.Colors.textSecondary
    }

    private var eyebrowColor: Color {
        surface == .darkShell ? MoveMarkTheme.Colors.limeAccent : MoveMarkTheme.Colors.primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(eyebrowColor)

            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)

            Text(subtitle)
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(subtitleColor)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(MoveMarkTheme.Colors.primary)
                .frame(width: 40, height: 3)
                .clipShape(Capsule())
                .padding(.top, 4)
        }
    }
}
