//
//  MMEmptyState.swift
//  movemork
//
//  MoveMark — Empty state card with CTA.
//

import SwiftUI

struct MMEmptyState: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                MMButton(title: buttonTitle, action: action)
            }
        }
    }
}
