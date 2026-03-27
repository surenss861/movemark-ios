//
//  MMMotion.swift
//  movemork
//
//  Motion tokens: deliberate, calm, no bounce. State changes clarify, not decorate.
//

import SwiftUI

enum MMMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let fastFade = Animation.easeOut(duration: 0.18)
    static let cardReveal = Animation.easeOut(duration: 0.24)
    static let screenTransition = Animation.easeOut(duration: 0.26)
    static let expand = Animation.spring(response: 0.34, dampingFraction: 0.88)
    static let tabSwitch = Animation.easeOut(duration: 0.22)
}
