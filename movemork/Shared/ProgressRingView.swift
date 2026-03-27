//
//  ProgressRingView.swift
//  movemork
//
//  MoveMark — Circular progress ring for vault and walkthrough.
//

import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    var size: CGFloat = 58
    var lineWidth: CGFloat = 4
    var label: String? = nil

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(MoveMarkTheme.Colors.fieldFill, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            MoveMarkTheme.Colors.primary.opacity(0.7),
                            MoveMarkTheme.Colors.primary
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if let label {
                Text(label)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}
