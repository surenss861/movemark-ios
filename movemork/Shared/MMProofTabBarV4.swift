//
//  MMProofTabBarV4.swift
//  movemork
//
//  The shared root navigation: one compact floating dock — Proof · Reports · Account — on the three root
//  surfaces only (the shell hides it on pushed screens, camera, receipt and modals). The active tab is
//  near-black with a short lime line under it; lime stays a signal, never a fill.
//

import SwiftUI

struct MMProofTabBarV4: View {
    @Binding var selectedTab: RootTab

    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var keyboardVisible = false

    private enum Ink {
        static let surface = Color(red: 0.980, green: 0.980, blue: 0.973)      // #FAFAF8, warm off-white
        static let border = Color.black.opacity(0.07)
        static let ink = Color(red: 0.078, green: 0.078, blue: 0.082)          // #141415
        static let idle = Color(red: 0.541, green: 0.545, blue: 0.553)         // #8A8B8D
        static let lime = Color(red: 0.792, green: 0.890, blue: 0.424)         // #CAE36C, as every action
    }

    var body: some View {
        Group {
            if !keyboardVisible {
                HStack(spacing: 0) {
                    item(.vaults, title: "Proof", outline: "house", filled: "house.fill")
                    item(.exports, title: "Reports", outline: "doc.text", filled: "doc.text.fill")
                    item(.account, title: "Account", outline: "person", filled: "person.fill")
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: MoveMarkTheme.Spacing.floatingDockHeight)
                .background(Ink.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Ink.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 14, y: 4)
                .padding(.horizontal, 22)
                .padding(.bottom, MoveMarkTheme.Spacing.floatingDockBottomInset)
                // Labels grow with Dynamic Type up to a size a dock can hold without clipping.
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            }
        }
        // The dock sits behind the keyboard rather than riding above it.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
    }

    private func item(_ tab: RootTab, title: String, outline: String, filled: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            guard selectedTab != tab else { return }
            MMHaptics.selection()
            withAnimation(reduceMotion ? nil : MMMotion.tabSwitch) { selectedTab = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? filled : outline)
                    .font(.system(size: 21, weight: .regular))
                    .frame(height: 24)
                Text(title)
                    .mmFont(11.5, .semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Ink.lime)
                            .matchedGeometryEffect(id: "dockSignal", in: tabNamespace)
                    }
                }
                .frame(width: 22, height: 3)
            }
            .foregroundStyle(isSelected ? Ink.ink : Ink.idle)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMFloatingDockPressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MMFloatingDockPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .animation(reduceMotion ? nil : MMMotion.spring, value: configuration.isPressed)
    }
}
