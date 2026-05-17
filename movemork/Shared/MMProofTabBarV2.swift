//
//  MMProofTabBarV2.swift
//  movemork
//
//  Quiet floating nav — active state is subtle, not a primary CTA pill.
//

import SwiftUI

struct MMProofTabBarV2: View {
    @Binding var selectedTab: RootTab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressedTab: RootTab? = nil

    private let barHeight: CGFloat = 74
    private let iconSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.vaults, title: "Vaults", systemImage: "archivebox")
            tabItem(.exports, title: "Reports", systemImage: "doc.text")
            tabItem(.account, title: "Account", systemImage: "person.crop.circle")
        }
        .frame(height: barHeight)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(MoveMarkTheme.Colors.tabBarFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func tabItem(_ tab: RootTab, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab
        let isPressed = pressedTab == tab

        Button {
            guard selectedTab != tab else { return }
            MMHaptics.selection()
            withAnimation(reduceMotion ? nil : MMMotion.tabSwitch) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(MoveMarkTheme.Colors.primary.opacity(0.14))
                            .frame(width: 30, height: 30)
                    }

                    Image(systemName: systemImage)
                        .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            isSelected
                                ? MoveMarkTheme.Colors.textPrimary
                                : MoveMarkTheme.Colors.limeAccent.opacity(0.62)
                        )
                }
                .frame(height: 30)

                if isSelected {
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary)
                        .frame(width: 22, height: 2.5)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }

                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected
                            ? MoveMarkTheme.Colors.textPrimary
                            : MoveMarkTheme.Colors.limeAccent.opacity(0.58)
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : MMMotion.press, value: isPressed)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if pressedTab != tab { pressedTab = tab }
                }
                .onEnded { _ in pressedTab = nil }
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
