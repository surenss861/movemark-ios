//
//  MMArtifactSurface.swift
//  movemork
//
//  MoveMark — Light report preview surface.
//

import SwiftUI

struct MMArtifactSurface<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    MoveMarkTheme.Colors.panel,
                    MoveMarkTheme.Colors.mint.opacity(0.55),
                    MoveMarkTheme.Colors.panelAlt
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MoveMarkTheme.Colors.panel.opacity(0.7))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(6)
                .offset(x: 3, y: 3)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)

            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(MoveMarkTheme.Colors.panelStroke.opacity(0.6))
                        .frame(width: 24, height: 4)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 20)
            .padding(.leading, 8)

            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke, lineWidth: 1)
        )
    }
}
