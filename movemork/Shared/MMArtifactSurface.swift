//
//  MMArtifactSurface.swift
//  movemork
//
//  MoveMark — Document/report-style surface with optional content overlay.
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
                    Color(red: 0.095, green: 0.092, blue: 0.09),
                    Color(red: 0.072, green: 0.071, blue: 0.073),
                    Color(red: 0.058, green: 0.057, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(6)
                .offset(x: 3, y: 3)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
                .offset(x: -2, y: -2)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .frame(width: 72, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .offset(x: 20, y: 24)

            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 24, height: 4)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 20)
            .padding(.leading, 8)

            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(MoveMarkTheme.Colors.primary.opacity(0.07))
                .frame(width: 70, height: 36)
                .offset(x: 18, y: 14)

            content
        }
    }
}
