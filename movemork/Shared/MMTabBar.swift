//
//  MMTabBar.swift
//  movemork
//
//  Quiet native rail — root-only, low chrome. Dark flat band, hairline separation,
//  icon + label; active = stronger icon/label + tiny marker. No glass, blur, or lift.
//

import SwiftUI

struct MMTabBar: View {
    @Binding var selectedTab: RootTab

    private let iconSize: CGFloat = 20
    private let iconLabelSpacing: CGFloat = 2
    private let markerWidth: CGFloat = 12
    private let markerHeight: CGFloat = 1.5

    private var labelFont: Font {
        .system(size: 9.5, weight: .medium, design: .default)
    }
    private var labelFontSelected: Font {
        .system(size: 9.5, weight: .semibold, design: .default)
    }

    /// Barely lifted from page background — infrastructure, not a footer “object.”
    private var railFill: Color {
        Color(red: 0.038, green: 0.038, blue: 0.042)
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                tabItem(.vaults, title: "Vaults", systemImage: "archivebox.fill")
                tabItem(.exports, title: "Exports", systemImage: "arrow.up.doc.fill")
                tabItem(.account, title: "Account", systemImage: "person.crop.circle.fill")
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 3)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .background(railFill)
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
                    Color.clear.frame(height: 1)

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
                                ? AnyShapeStyle(MoveMarkTheme.Colors.primary)
                                : AnyShapeStyle(Color.white.opacity(0.52))
                        )

                    Text(title)
                        .font(isSelected ? labelFontSelected : labelFont)
                        .foregroundStyle(
                            isSelected
                                ? AnyShapeStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.92))
                                : AnyShapeStyle(Color.white.opacity(0.56))
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
