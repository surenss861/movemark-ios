//
//  PropertyVaultWalkthroughBar.swift
//  movemork
//
//  Dominant CTA: room proof with subtitle and progress.
//

import SwiftUI

struct PropertyVaultWalkthroughBar: View {
    let subtitle: String
    let progressText: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    MoveMarkTheme.Colors.primary.opacity(0.22),
                                    MoveMarkTheme.Colors.primary.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(MoveMarkTheme.Colors.primary.opacity(0.18), lineWidth: 0.9)
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Room proof")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .lineLimit(1)

                    Text(progressText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(MoveMarkTheme.Colors.mint.opacity(0.65))
                        .frame(width: 34, height: 34)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(MoveMarkTheme.Colors.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.primary.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: MoveMarkTheme.Colors.textPrimary.opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}
