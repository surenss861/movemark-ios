//
//  MMMotionModifiers.swift
//  movemork
//
//  MoveMark Motion System v1 — category-based motion (navigation, press, proof, sheets).
//

import SwiftUI

extension MMMotion {
    static let quick = Animation.easeOut(duration: 0.18)
    static let smooth = Animation.easeInOut(duration: 0.26)
    static let spring = Animation.spring(response: 0.36, dampingFraction: 0.82)
    static let softSpring = Animation.spring(response: 0.46, dampingFraction: 0.9)
    static let sheetLift = Animation.spring(response: 0.42, dampingFraction: 0.88)
    static let statusMorph = Animation.easeInOut(duration: 0.22)
}

// MARK: - Press

extension View {
    /// Primary/secondary control press — scale 0.97 + spring release.
    func mmPressable(scale: CGFloat = 0.97) -> some View {
        buttonStyle(MMPressableButtonStyle(scale: scale))
    }
}

private struct MMPressableButtonStyle: ButtonStyle {
    let scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .animation(reduceMotion ? nil : MMMotion.spring, value: configuration.isPressed)
    }
}

// MARK: - Appear

extension View {
    /// Fade + small upward slide for screen sections and list rows.
    func mmAppearRise(isVisible: Bool, delay: Double = 0, offset: CGFloat = 6) -> some View {
        modifier(MMAppearRiseModifier(isVisible: isVisible, delay: delay, offset: offset))
    }
}

private struct MMAppearRiseModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double
    let offset: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : offset)
            .animation(
                reduceMotion ? nil : MMMotion.quick.delay(delay),
                value: isVisible
            )
    }
}

// MARK: - Proof saved pulse

extension View {
    func mmProofSavedPulse(active: Bool) -> some View {
        modifier(MMProofSavedPulseModifier(active: active))
    }
}

private struct MMProofSavedPulseModifier: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if active, !reduceMotion {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.primary.opacity(0.55), lineWidth: 2)
                        .scaleEffect(active ? 1.02 : 1)
                        .opacity(active ? 0.9 : 0)
                        .animation(MMMotion.softSpring, value: active)
                }
            }
    }
}

// MARK: - Row status

extension View {
    /// Soft transition when row status copy changes.
    func mmRowStatusTransition(value: some Equatable) -> some View {
        contentTransition(.opacity)
            .animation(MMMotion.statusMorph, value: value)
    }
}

// MARK: - Sheet entrance

extension View {
    func mmSheetEntrance(isPresented: Bool) -> some View {
        modifier(MMSheetEntranceModifier(isPresented: isPresented))
    }
}

private struct MMSheetEntranceModifier: ViewModifier {
    let isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isPresented ? 1 : 0)
            .offset(y: isPresented ? 0 : 12)
            .animation(reduceMotion ? nil : MMMotion.sheetLift, value: isPresented)
    }
}
