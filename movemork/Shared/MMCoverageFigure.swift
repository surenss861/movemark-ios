//
//  MMCoverageFigure.swift
//  movemork
//
//  The coverage statement. Large numerals carry the progress; the label only names it.
//

import SwiftUI

struct MMCoverageFigure: View {
    let documented: Int
    let total: Int
    var kicker: String = "Move-in coverage"
    var caption: String = "Rooms documented"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker.uppercased())
                .font(MoveMarkTheme.Typography.kicker)
                .tracking(1.15)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(padded(documented))
                    .font(MoveMarkTheme.Typography.coverageFigure)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .contentTransition(.numericText())
                Text("/")
                    .font(MoveMarkTheme.Typography.editorialTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                Text(padded(total))
                    .font(MoveMarkTheme.Typography.coverageFigure)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.72))
                    .contentTransition(.numericText())
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .animation(reduceMotion ? nil : MMMotion.proofProgress, value: documented)

            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(caption.uppercased().split(separator: " ").enumerated()), id: \.offset) { _, word in
                    Text(String(word))
                        .font(MoveMarkTheme.Typography.kicker)
                        .tracking(0.6)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kicker), \(documented) of \(total) \(caption.lowercased())")
    }

    private func padded(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}
