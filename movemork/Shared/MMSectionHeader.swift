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
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
        }
    }
}
