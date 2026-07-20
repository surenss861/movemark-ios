//
//  MMSectionHeader.swift
//  movemork
//
//  MoveMark — Section title and subtitle.
//

import SwiftUI

struct MMSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MoveMarkTheme.Typography.cardTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
        }
    }
}
