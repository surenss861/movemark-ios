//
//  MMNextActionCard.swift
//  movemork
//
//  Signature MoveMark component: one obvious next action.
//

import SwiftUI

struct MMNextActionCard: View {
    let title: String
    let message: String
    var metric: String? = nil
    let primaryTitle: String
    let onPrimary: () -> Void

    var body: some View {
        MMCard(tone: .standard, padding: 18, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(MoveMarkTheme.Typography.cardTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(message)
                            .font(MoveMarkTheme.Typography.subheadline)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if let metric, !metric.isEmpty {
                        MMPill(text: metric, tone: .neutral)
                    }
                }

                MMButton(
                    title: primaryTitle,
                    action: {
                        MMHaptics.soft()
                        onPrimary()
                    },
                    kind: .primary,
                    size: .standard
                )
            }
        }
    }
}

