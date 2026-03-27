//
//  MMErrorBanner.swift
//  movemork
//
//  MoveMark — Consistent error display with optional retry.
//

import SwiftUI

struct MMErrorBanner: View {
    let message: String
    var retryTitle: String? = "Try again"
    var onRetry: (() -> Void)? = nil

    var body: some View {
        MMCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange.opacity(0.9))

                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    if let retryTitle, let onRetry {
                        Button(action: onRetry) {
                            Text(retryTitle)
                                .font(MoveMarkTheme.Typography.footnote)
                                .foregroundStyle(MoveMarkTheme.Colors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(4)
        }
    }
}
