//
//  MMTabBar.swift
//  movemork
//
//  Wise-style floating pill tab rail on emerald shell.
//

import SwiftUI

struct MMTabBar: View {
    @Binding var selectedTab: RootTab

    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let iconSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 4) {
            tabItem(.vaults, title: "Vaults", systemImage: "archivebox")
            tabItem(.exports, title: "Reports", systemImage: "doc.text")
            tabItem(.account, title: "Account", systemImage: "person.crop.circle")
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.55), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 8, y: 3)
        )
        .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [
                    MoveMarkTheme.Colors.appBackground.opacity(0),
                    MoveMarkTheme.Colors.appBackground.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func tabItem(_ tab: RootTab, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab

        Button {
            guard selectedTab != tab else { return }
            MMHaptics.selection()
            withAnimation(reduceMotion ? nil : MMMotion.tabSwitch) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        isSelected
                            ? MoveMarkTheme.Colors.textOnPrimary
                            : MoveMarkTheme.Colors.limeAccent.opacity(0.75)
                    )

                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected
                            ? MoveMarkTheme.Colors.textOnPrimary
                            : MoveMarkTheme.Colors.textMuted
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MoveMarkTheme.Colors.primary.opacity(0.92))
                        .matchedGeometryEffect(id: "tabPill", in: tabNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
