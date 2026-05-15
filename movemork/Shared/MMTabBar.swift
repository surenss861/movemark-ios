//
//  MMTabBar.swift
//  movemork
//
//  Light root tab rail — white band, green active state, obvious labels.
//

import SwiftUI

struct MMTabBar: View {
    @Binding var selectedTab: RootTab

    private let iconSize: CGFloat = 22
    private let iconLabelSpacing: CGFloat = 3
    private let markerWidth: CGFloat = 20
    private let markerHeight: CGFloat = 2.5

    private var labelFont: Font {
        .system(size: 10, weight: .medium, design: .default)
    }
    private var labelFontSelected: Font {
        .system(size: 10, weight: .semibold, design: .default)
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.panelStroke)
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                tabItem(.vaults, title: "Vaults", systemImage: "archivebox.fill")
                tabItem(.exports, title: "Reports", systemImage: "doc.text.fill")
                tabItem(.account, title: "Account", systemImage: "person.crop.circle.fill")
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .background(MoveMarkTheme.Colors.panel.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func tabItem(_ tab: RootTab, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == tab

        Button {
            guard selectedTab != tab else { return }
            selectedTab = tab
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    Color.clear.frame(height: 2)

                    if isSelected {
                        Capsule()
                            .fill(MoveMarkTheme.Colors.primary)
                            .frame(width: markerWidth, height: markerHeight)
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(MMMotion.tabSwitch, value: selectedTab)

                VStack(spacing: iconLabelSpacing) {
                    Image(systemName: systemImage)
                        .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            isSelected
                                ? MoveMarkTheme.Colors.primary
                                : MoveMarkTheme.Colors.textSecondary
                        )

                    Text(title)
                        .font(isSelected ? labelFontSelected : labelFont)
                        .foregroundStyle(
                            isSelected
                                ? MoveMarkTheme.Colors.textDarkGreen
                                : MoveMarkTheme.Colors.textSecondary
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 2)
                .padding(.top, 2)
                .padding(.bottom, 1)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
