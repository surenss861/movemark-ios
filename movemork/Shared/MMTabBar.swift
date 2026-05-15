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

    private let iconSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 6) {
            tabItem(.vaults, title: "Vaults", systemImage: "archivebox.fill")
            tabItem(.exports, title: "Reports", systemImage: "doc.text.fill")
            tabItem(.account, title: "Account", systemImage: "person.crop.circle.fill")
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.94))
                .background(.ultraThinMaterial.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.85), lineWidth: 1)
                )
                .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.2), radius: 22, y: 8)
        )
        .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
        .padding(.top, 8)
        .padding(.bottom, 10)
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
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        isSelected
                            ? MoveMarkTheme.Colors.textOnPrimary
                            : MoveMarkTheme.Colors.textMuted
                    )

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(
                        isSelected
                            ? MoveMarkTheme.Colors.textOnPrimary
                            : MoveMarkTheme.Colors.textMuted
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(MoveMarkTheme.Colors.primary)
                        .matchedGeometryEffect(id: "tabPill", in: tabNamespace)
                        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.45), radius: 10, y: 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
