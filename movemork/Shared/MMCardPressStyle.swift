//
//  MMCardPressStyle.swift
//  movemork
//
//  Press feedback: scale + opacity, no haptic here (haptic on tap action).
//

import SwiftUI

struct MMCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(MMMotion.press, value: configuration.isPressed)
    }
}
