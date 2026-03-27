//
//  PressResponsiveCard.swift
//  movemork
//
//  Wrapper that exposes isPressed so card content can react (media zoom, overlay, CTA).
//

import SwiftUI

struct PressResponsiveCard<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: (_ isPressed: Bool) -> Content

    @State private var isPressed = false

    var body: some View {
        Button {
            MMHaptics.selection()
            action()
        } label: {
            content(isPressed)
                .scaleEffect(isPressed ? 0.985 : 1.0)
                .animation(MMMotion.press, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}
