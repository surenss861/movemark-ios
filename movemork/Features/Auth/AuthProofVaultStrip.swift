//
//  AuthProofVaultStrip.swift
//  movemork
//
//  Compact auth proof context — vault strip or trust rows. No dashboard card.
//

import SwiftUI

struct AuthProofVaultStrip: View {
    let mode: AuthContainerView.Mode

    private let stripRadius: CGFloat = 14
    private let trustItems = [
        "Private proof vault",
        "Move-in report included",
        "Upgrade later for move-out and disputes",
    ]

    var body: some View {
        Group {
            if mode == .signIn {
                signInStrip
            } else {
                signUpTrustRows
            }
        }
        .id("auth-strip-\(mode == .signIn ? "in" : "up")")
    }

    private var signInStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.9))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text("Proof vault ready")
                    .font(MoveMarkTheme.Typography.detailEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text("Pick up where your room proof left off.")
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Move-in proof · Reports when needed")
                    .font(MoveMarkTheme.Typography.tinyMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .lineLimit(1)
                    .padding(.top, 1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(stripBackground)
    }

    private var signUpTrustRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(trustItems, id: \.self) { item in
                trustRow(item)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(stripBackground)
    }

    private func trustRow(_ label: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(MoveMarkTheme.Typography.footnoteEmphasis)
                .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.88))

            Text(label)
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stripBackground: some View {
        RoundedRectangle(cornerRadius: stripRadius, style: .continuous)
            .fill(MoveMarkTheme.Colors.evidenceCardRaised.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: stripRadius, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.55), lineWidth: 0.75)
            )
    }
}
