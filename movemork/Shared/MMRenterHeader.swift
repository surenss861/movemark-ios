//
//  MMRenterHeader.swift
//  movemork
//
//  Compact renter-facing screen header — proof camera, not dashboard.
//

import SwiftUI

struct MMRenterHeader: View {
    let title: String
    let subtitle: String
    var eyebrow: String? = nil
    var onAdd: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }

                Text(title)
                    .font(MoveMarkTheme.Typography.cardValue)
                    .tracking(-0.5)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(MoveMarkTheme.Typography.body)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textOnPrimary)
                        .frame(width: 36, height: 36)
                        .background(MoveMarkTheme.Colors.primary.opacity(0.92))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add")
            }
        }
        .padding(.bottom, 4)
    }
}
