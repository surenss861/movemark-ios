//
//  MMProofTabBarV4.swift
//  movemork
//
//  The shared root navigation: one compact floating dock — Proof · Reports · Account — on the three root
//  surfaces only (the shell hides it on pushed screens, camera, receipt and modals). Dark and centred, at most
//  310pt wide; the active tab sits in a soft pill.
//

import SwiftUI

struct MMProofTabBarV4: View {
    @Binding var selectedTab: RootTab
    /// The already-selected item tapped again: the shell pops that tab to its root or scrolls it to the top.
    var onReselect: (RootTab) -> Void = { _ in }

    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var keyboardVisible = false

    private let cornerRadius: CGFloat = 26
    private var idle: Color { MoveMarkTheme.Colors.textSecondary.opacity(0.82) }

    var body: some View {
        Group {
            if !keyboardVisible {
                HStack(spacing: 0) {
                    item(.vaults, title: "Proof", outline: "folder", filled: "folder.fill")
                    item(.exports, title: "Reports", outline: "doc.text", filled: "doc.text.fill")
                    item(.account, title: "Account", outline: "person.crop.circle", filled: "person.crop.circle.fill")
                }
                .frame(maxWidth: 310, minHeight: MoveMarkTheme.Spacing.floatingDockHeight)
                .background(dockBackground)
                .overlay(dockBorder)
                .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity)
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

    private var dockBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            // Solid: at 96% the page's text showed through the labels.
            .fill(MoveMarkTheme.Colors.evidenceCardRaised)
    }

    private var dockBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [MoveMarkTheme.Colors.primary.opacity(0.28), MoveMarkTheme.Colors.cardStroke.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private func item(_ tab: RootTab, title: String, outline: String, filled: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            guard selectedTab != tab else {
                onReselect(tab)
                return
            }
            MMHaptics.selection()
            withAnimation(reduceMotion ? nil : MMMotion.tabIndicator) { selectedTab = tab }
        } label: {
            VStack(spacing: isSelected ? 4 : 2) {
                Image(systemName: isSelected ? filled : outline)
                    .font(.system(size: 21, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(isSelected && !reduceMotion ? 1.04 : 1)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                Text(title)
                    .mmFont(10, isSelected ? .semibold : .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .opacity(isSelected ? 1 : 0.9)
            }
            .foregroundStyle(isSelected ? MoveMarkTheme.Colors.textPrimary : idle)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary.opacity(0.14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .matchedGeometryEffect(id: "evidenceDockPill", in: tabNamespace)
                }
            }
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
