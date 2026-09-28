//
//  MMProofTabBarV4.swift
//  movemork
//
//  Floating evidence dock — premium utility nav above the home indicator.
//

import SwiftUI

struct MMProofTabBarV4: View {
    @Binding var selectedTab: RootTab

    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dockHeight: CGFloat = MoveMarkTheme.Spacing.floatingDockHeight
    private let dockCornerRadius: CGFloat = 24
    private let iconSize: CGFloat = 19

    private var inactiveForeground: Color {
        MoveMarkTheme.Colors.textSecondary.opacity(0.82)
    }

    var body: some View {
        GeometryReader { geo in
            let dockWidth = min(max(geo.size.width - 64, 250), 292)

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
            .frame(width: dockWidth, height: dockHeight)
            .background(dockBackground)
            .overlay(dockBorder)
            .shadow(color: Color.black.opacity(0.28), radius: 12, x: 0, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, MoveMarkTheme.Spacing.floatingDockBottomInset)
        }
        .frame(height: dockHeight + MoveMarkTheme.Spacing.floatingDockBottomInset)
    }

    private var dockBackground: some View {
        RoundedRectangle(cornerRadius: dockCornerRadius, style: .continuous)
            .fill(MoveMarkTheme.Colors.evidenceCardRaised.opacity(0.96))
            .background(
                RoundedRectangle(cornerRadius: dockCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.18))
            )
    }

    private var dockBorder: some View {
        RoundedRectangle(cornerRadius: dockCornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        MoveMarkTheme.Stroke.interactive,
                        MoveMarkTheme.Stroke.normal
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
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
            VStack(spacing: 2) {
                Image(systemName: isSelected ? filledImage : outlineImage)
                    .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? MoveMarkTheme.Colors.primary : inactiveForeground)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(reduceMotion ? nil : MMMotion.quick, value: isSelected)

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? MoveMarkTheme.Colors.textPrimary : inactiveForeground)
                    .opacity(isSelected ? 1 : 0.9)
                    .animation(reduceMotion ? nil : MMMotion.quick, value: isSelected)
            }
            .padding(.horizontal, 12)
            .frame(minWidth: 72, minHeight: 46)
            .background {
                if isSelected {
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary.opacity(0.16))
                        .overlay(Capsule().stroke(MoveMarkTheme.Stroke.selected, lineWidth: 0.75))
                        .matchedGeometryEffect(id: "evidenceDockPill", in: tabNamespace)
                }
            }
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
