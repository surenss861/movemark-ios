//
//  VaultFeedbackToast.swift
//  movemork
//
//  Lightweight success toast for workflow feedback (document upload, readiness, exports).
//

import SwiftUI

struct VaultFeedbackToast: View {
    let message: VaultFeedbackMessage

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(MoveMarkTheme.Colors.primary.opacity(0.16))
                    .frame(width: 32, height: 32)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                if let subtitle = message.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(MoveMarkTheme.Colors.panel.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.55), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}
