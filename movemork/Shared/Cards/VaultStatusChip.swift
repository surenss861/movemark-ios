//
//  VaultStatusChip.swift
//  movemork
//
//  Top-right status chip: dot + label. Premium, not loud.
//

import SwiftUI

struct VaultStatusChip: View {
    let text: String
    /// When true (e.g. "Recent"), show the accent dot.
    var showDot: Bool = true

    var body: some View {
        HStack(spacing: 3) {
            if showDot {
                Circle()
                    .fill(MoveMarkTheme.Colors.primary)
                    .frame(width: 3, height: 3)
            }
            Text(text)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05), in: Capsule())
    }
}
