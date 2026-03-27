//
//  MMLoadingState.swift
//  movemork
//
//  MoveMark — Full-screen loading state for consistent UX.
//

import SwiftUI

struct MMLoadingState: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(MoveMarkTheme.Colors.primary)
                .scaleEffect(1.15)

            Text(message)
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
