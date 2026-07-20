//
//  VaultStatusChip.swift
//  movemork
//
//  Top-right status chip on vault covers.
//

import SwiftUI

struct VaultStatusChip: View {
    let text: String
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
        .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(MoveMarkTheme.Colors.card.opacity(0.92), in: Capsule())
        .overlay(
            Capsule()
                .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 0.6)
        )
    }
}
