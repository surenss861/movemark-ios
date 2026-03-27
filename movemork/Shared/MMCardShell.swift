//
//  MMCardShell.swift
//  movemork
//
//  MoveMark v4 — Shared card shell: dark graphite body, crisp edge, one shadow/radius family.
//

import SwiftUI

struct MMCardShell<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var padding: CGFloat = 18
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.085, green: 0.085, blue: 0.090),
                                Color(red: 0.070, green: 0.070, blue: 0.075)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
