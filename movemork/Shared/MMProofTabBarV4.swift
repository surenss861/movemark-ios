//
//  MMProofTabBarV4.swift
//  movemork
//
//  Quiet native tab bar — invisible navigation, proof stays the hero.
//

import SwiftUI

struct MMProofTabBarV4: View {
    @Binding var selectedTab: RootTab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let contentHeight: CGFloat = MoveMarkTheme.Spacing.rootTabBarContentHeight
    private let iconSize: CGFloat = 22

    private var inactiveForeground: Color {
        MoveMarkTheme.Colors.textMuted.opacity(0.77)
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            HStack(spacing: 0) {
                tabItem(
                    .vaults,
                    title: "Proof",
                    outlineImage: "folder",
                    filledImage: "folder.fill"
                )
                tabItem(
                    .exports,
                    title: "Reports",
                    outlineImage: "doc.text",
                    filledImage: "doc.text.fill"
                )
                tabItem(
                    .account,
                    title: "Account",
                    outlineImage: "person.crop.circle",
                    filledImage: "person.crop.circle.fill"
                )
            }
            .padding(.top, 8)
            .frame(height: contentHeight)
        }
        .background(barBackground)
    }

    private var barBackground: some View {
        ZStack {
            MoveMarkTheme.Colors.appBackground.opacity(0.97)
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.28))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func tabItem(
        _ tab: RootTab,
        title: String,
        outlineImage: String,
        filledImage: String
    ) -> some View {
        let isSelected = selectedTab == tab

        Button {
            guard selectedTab != tab else { return }
            MMHaptics.selection()
            withAnimation(reduceMotion ? nil : MMMotion.tabSwitch) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? filledImage : outlineImage)
                    .font(.system(size: iconSize, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? MoveMarkTheme.Colors.textPrimary : inactiveForeground)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(reduceMotion ? nil : MMMotion.quick, value: isSelected)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? MoveMarkTheme.Colors.textPrimary : inactiveForeground)
                    .animation(reduceMotion ? nil : MMMotion.quick, value: isSelected)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMTabQuietPressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MMTabQuietPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : MMMotion.spring, value: configuration.isPressed)
    }
}
