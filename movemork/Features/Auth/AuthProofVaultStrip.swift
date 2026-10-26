//
//  AuthProofVaultStrip.swift
//  movemork
//
//  Compact auth proof context — what the vault holds, as one quiet grouped container on the sheet.
//

import SwiftUI

struct AuthProofVaultStrip: View {
    let mode: AuthContainerView.Mode

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
        MMPanel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(MMInk.text.opacity(0.75))
                    .frame(width: 24)
                    .padding(.top, 1)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Proof vault ready")
                        .mmFont(16, .semibold)
                        .foregroundStyle(MMInk.text)

                    Text("Pick up where your room proof left off.")
                        .mmFont(14)
                        .foregroundStyle(MMInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Move-in proof · Reports when needed")
                        .mmFont(12.5)
                        .foregroundStyle(MMInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var signUpTrustRows: some View {
        MMGroup {
            ForEach(Array(trustItems.enumerated()), id: \.element) { index, item in
                if index > 0 { MMRowDivider(leading: 52) }
                MMRow(title: item, icon: "checkmark", accessory: .none)
            }
        }
    }
}
