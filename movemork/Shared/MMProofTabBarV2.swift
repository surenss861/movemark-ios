//
//  MMProofTabBarV2.swift
//  movemork
//
//  Calm utility dock — navigation only, never competes with page CTAs.
//

import SwiftUI

struct MMProofTabBarV2: View {
    @Binding var selectedTab: RootTab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressedTab: RootTab? = nil

    private let barHeight: CGFloat = 56
    private let iconSize: CGFloat = 18

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.vaults, title: "Vaults", systemImage: "archivebox")
            tabItem(.exports, title: "Reports", systemImage: "doc.text")
            tabItem(.account, title: "Account", systemImage: "person.crop.circle")
        }
        .frame(height: barHeight)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MoveMarkTheme.Colors.tabBarFill.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func tabItem(_ tab: RootTab, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab
        let isPressed = pressedTab == tab

        Button {
            guard selectedTab != tab else { return }
            MMHaptics.selection()
            withAnimation(reduceMotion ? nil : MMMotion.quick) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        isSelected
                            ? MoveMarkTheme.Colors.textPrimary
                            : MoveMarkTheme.Colors.textMuted.opacity(0.85)
                    )
                    .frame(height: 20)
                    .offset(y: isSelected && !reduceMotion ? -1 : 0)
                    .animation(reduceMotion ? nil : MMMotion.quick, value: isSelected)

                if isSelected {
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary)
                        .frame(width: 20, height: 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    Color.clear.frame(width: 20, height: 2)
                }

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected
                            ? MoveMarkTheme.Colors.textPrimary
                            : MoveMarkTheme.Colors.textMuted.opacity(0.78)
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : MMMotion.spring, value: isPressed)
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
