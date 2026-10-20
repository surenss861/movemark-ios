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

    /// Proof is the first light screen; the dock goes light with it. Reports and Account switch
    /// when they're rebuilt (VISUAL_STANDARD rollout).
    private var isLight: Bool { selectedTab == .vaults }

    private var inactiveForeground: Color {
        isLight ? MoveMarkTheme.Light.textSecondary : MoveMarkTheme.Colors.textSecondary.opacity(0.82)
    }

    var body: some View {
        if isLight {
            lightBar
        } else {
            floatingDock
        }
    }

    // MARK: - Light bar (Proof redesign): attached to the bottom edge, full width, native material.

    private var lightBar: some View {
        HStack(spacing: 0) {
            lightItem(.vaults, title: "Proof", outline: "house", filled: "house.fill")
            lightItem(.exports, title: "Reports", outline: "doc.text", filled: "doc.text.fill")
            lightItem(.account, title: "Account", outline: "person", filled: "person.fill")
        }
        .padding(.horizontal, 6)
        .padding(.top, 1)
        .frame(maxWidth: .infinity)
        // Same surface as the Proof sheet, so the bar reads as part of it (reference treatment).
        .background(Color(red: 0.973, green: 0.973, blue: 0.973), ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
        }
    }

    private func lightItem(_ tab: RootTab, title: String, outline: String, filled: String) -> some View {
        let isSelected = selectedTab == tab
        let ink = Color(red: 0.067, green: 0.110, blue: 0.067)               // #111C11
        let idle = Color(red: 0.56, green: 0.56, blue: 0.57)
        return Button {
            guard selectedTab != tab else { return }
            MMHaptics.selection()
            withAnimation(reduceMotion ? nil : MMMotion.tabSwitch) { selectedTab = tab }
        } label: {
            VStack(spacing: -6) {
                Image(systemName: isSelected ? filled : outline)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(isSelected ? ink : idle)
                    .frame(width: 33, height: 33)
                    .background {
                        if isSelected {
                            Circle()
                                .fill(Color(red: 0.914, green: 0.914, blue: 0.914))    // #E9E9E9
                                .matchedGeometryEffect(id: "lightTabPill", in: tabNamespace)
                        }
                    }
                Text(title)
                    .font(.system(size: 8.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ink : idle)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMFloatingDockPressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Floating dock (screens not yet redesigned)

    private var floatingDock: some View {
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

    @ViewBuilder
    private var dockBackground: some View {
        if isLight {
            RoundedRectangle(cornerRadius: dockCornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .environment(\.colorScheme, .light)
        } else {
        RoundedRectangle(cornerRadius: dockCornerRadius, style: .continuous)
            .fill(MoveMarkTheme.Colors.evidenceCardRaised.opacity(0.96))
            .background(
                RoundedRectangle(cornerRadius: dockCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.18))
            )
        }
    }

    private var dockBorder: some View {
        RoundedRectangle(cornerRadius: dockCornerRadius, style: .continuous)
            .stroke(isLight ? AnyShapeStyle(MoveMarkTheme.Light.hairline) : AnyShapeStyle(
                LinearGradient(
                    colors: [
                        MoveMarkTheme.Stroke.interactive,
                        MoveMarkTheme.Stroke.normal
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )),
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
                    .foregroundStyle(isSelected ? (isLight ? MoveMarkTheme.Light.textPrimary : MoveMarkTheme.Colors.primary) : inactiveForeground)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(reduceMotion ? nil : MMMotion.quick, value: isSelected)

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? (isLight ? MoveMarkTheme.Light.textPrimary : MoveMarkTheme.Colors.textPrimary) : inactiveForeground)
                    .opacity(isSelected ? 1 : 0.9)
                    .animation(reduceMotion ? nil : MMMotion.quick, value: isSelected)
            }
            .padding(.horizontal, 12)
            .frame(minWidth: 72, minHeight: 46)
            .background {
                if isSelected {
                    Capsule()
                        .fill(isLight ? MoveMarkTheme.Light.accentWash : MoveMarkTheme.Colors.primary.opacity(0.16))
                        .overlay(Capsule().stroke(isLight ? Color.clear : MoveMarkTheme.Stroke.selected, lineWidth: 0.75))
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
