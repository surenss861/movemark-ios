//
//  WelcomeReportBackingCard.swift
//  movemork
//
//  One quiet report layer behind the proof passport.
//

import SwiftUI

struct WelcomeReportBackingCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(MoveMarkTheme.Colors.card.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .overlay {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MoveMarkTheme.Colors.paperSurface.opacity(0.08))
                        .frame(width: 72, height: 5)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MoveMarkTheme.Colors.paperSurface.opacity(0.05))
                        .frame(width: 100, height: 4)
                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.35), lineWidth: 1)
            )
            .rotationEffect(.degrees(5))
            .offset(x: 18, y: -14)
            .allowsHitTesting(false)
    }
}
