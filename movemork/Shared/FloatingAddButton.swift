//
//  FloatingAddButton.swift
//  movemork
//
//  FAB with subtle glow, press scale, icon rotation on tap. Restrained, not gimmicky.
//

import SwiftUI

struct FloatingAddButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            MMHaptics.soft()
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(MoveMarkTheme.Colors.primary.opacity(0.07))
                    .frame(width: 58, height: 58)
                    .blur(radius: 12)

                Circle()
                    .fill(MoveMarkTheme.Colors.background.opacity(0.98))
                    .overlay(
                        Circle()
                            .strokeBorder(MoveMarkTheme.Colors.panelStroke, lineWidth: 0.5)
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
                    .rotationEffect(.degrees(isPressed ? 45 : 0))
            }
            .scaleEffect(isPressed ? 0.94 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
