//
//  MMFloatingPillDock.swift
//  movemork
//
//  1.4.1 root dock, built from the user's reference: two charcoal capsules side by side that read as one
//  transforming object.
//  - Left, the expanded active capsule: a lime circle holding the active tab's icon in charcoal, then its title.
//  - Right, the compact capsule: the other destinations as icon-only 44 pt buttons.
//  Selecting a tab makes it the expanded capsule; the previous one drops into the compact group. The three tabs
//  are one row of persistent items that reorder, so each icon travels rather than fading out and in.
//
//  The dock never drives the page animation: the selection is set with animations off (the shell swaps pages
//  in one frame); the dock animates its own `visualTab` on its own spring, so a burst of taps navigates
//  immediately and the dock simply retargets.
//
//  Visual parameters live in `MMPillDockSpec`.
//

import SwiftUI

// MARK: - Which dock

/// The root dock in use. Internal `MM_NAV_LAB` builds can switch it (Account row, `-MMNavDock classic|pill`).
enum MMDockStyle: String, CaseIterable, Identifiable {
    case classic
    case pill

    var id: String { rawValue }
    var title: String { self == .classic ? "Classic" : "Pill" }

    static let shipping: MMDockStyle = .pill

    static var current: MMDockStyle {
        #if MM_NAV_LAB
        if let raw = UserDefaults.standard.string(forKey: MMNavLab.dockKey), let style = MMDockStyle(rawValue: raw) {
            return style
        }
        #endif
        return shipping
    }
}

/// The dock the root shell mounts. Same API and accessibility (buttons "Proof", "Reports", "Account", the
/// selected one carrying `.isSelected`) whichever style is in use.
struct MMRootDock: View {
    @Binding var selectedTab: RootTab
    var onReselect: (RootTab) -> Void = { _ in }
    var style: MMDockStyle = .current

    var body: some View {
        switch style {
        case .classic: MMProofTabBarV4(selectedTab: $selectedTab, onReselect: onReselect)
        case .pill: MMFloatingPillDock(selectedTab: $selectedTab, onReselect: onReselect)
        }
    }
}

// MARK: - Spec

/// Every visual parameter of the pill dock, from the user's reference.
enum MMPillDockSpec {
    static let lime = Color(red: 0.79, green: 0.96, blue: 0.47)
    static let charcoal = Color(red: 0.16, green: 0.18, blue: 0.16)
    static let ivory = Color(red: 0.96, green: 0.97, blue: 0.94)

    static let shadowColor = Color.black.opacity(0.16)
    static let shadowRadius: CGFloat = 14
    static let shadowY: CGFloat = 5

    /// Lime circle and compact buttons: also the hit target.
    static let button: CGFloat = 44
    static let capsulePadding: CGFloat = 5
    static let capsuleSpacing: CGFloat = 10          // between the two capsules
    static let iconTitleSpacing: CGFloat = 12        // lime circle to title
    static let compactSpacing: CGFloat = 4           // between compact buttons
    static let titleTrailingPadding: CGFloat = 14
    static let iconSize: CGFloat = 18
    static let iconWeight: Font.Weight = .semibold
    static let titleSize: CGFloat = 15
    static let titleWeight: Font.Weight = .semibold
    static let bottomInset: CGFloat = MoveMarkTheme.Spacing.floatingDockBottomInset
    static let screenInset: CGFloat = 16
    /// The title grows with Dynamic Type only this far, then scales down slightly; the dock never leaves the screen.
    static let maxDynamicType: DynamicTypeSize = .xxLarge
    static let titleMinimumScale: CGFloat = 0.8

    static let spring = MMMotion.tabDockPill
}

// MARK: - Pill dock

struct MMFloatingPillDock: View {
    @Binding var selectedTab: RootTab
    var onReselect: (RootTab) -> Void = { _ in }

    /// What the dock draws. Follows `selectedTab` on the dock's own animation; never read for navigation.
    @State private var visualTab: RootTab?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var keyboardVisible = false

    private typealias Spec = MMPillDockSpec
    private static let order: [RootTab] = [.vaults, .exports, .account]

    private var shown: RootTab { visualTab ?? selectedTab }

    /// Which tab sits in each compact slot. A selection swaps exactly two tabs: the new one leaves its slot for
    /// the lime circle and the previous one drops into that same slot; the third icon never moves between slots.
    @State private var compactSlots: [RootTab] = []
    /// For one frame after a tap: the lime circle sits behind the tapped icon in its compact slot, then travels
    /// with it into the active capsule, so the circle is never empty and the selected icon never flies alone.
    @State private var circleStart: CGPoint?
    /// The tab whose icon is already drawn on lime (from the tap until the dock has caught up).
    @State private var litTab: RootTab?
    /// When the dock last started changing; a tap while it is still moving retargets directly (see onChange).
    @State private var lastChange = Date.distantPast
    private var slots: [RootTab] {
        compactSlots.count == 2 && !compactSlots.contains(shown) ? compactSlots : Self.order.filter { $0 != shown }
    }

    /// Measured width of each title at the current text size (estimates until measured).
    @State private var titleWidths: [RootTab: CGFloat] = [.vaults: 40, .exports: 58, .account: 62]

    // Geometry. The two capsules are fixed structure: the active capsule's width follows the title, the
    // compact capsule never changes, and the lime circle never moves. Only the icons travel between the lime
    // circle and the compact slots, so the dock reads as one object changing state, never as parts collapsing.
    private var rowHeight: CGFloat { Spec.button + Spec.capsulePadding * 2 }
    private func activeWidth(_ tab: RootTab) -> CGFloat {
        Spec.capsulePadding + Spec.button + Spec.iconTitleSpacing + (titleWidths[tab] ?? 60) + Spec.titleTrailingPadding + Spec.capsulePadding
    }
    private var compactWidth: CGFloat { Spec.capsulePadding * 2 + Spec.button * 2 + Spec.compactSpacing }
    private var activeW: CGFloat { activeWidth(shown) }
    private var totalWidth: CGFloat { activeW + Spec.capsuleSpacing + compactWidth }
    private var compactX: CGFloat { activeW + Spec.capsuleSpacing }

    /// Centre of `tab`'s 44 pt button: in the lime circle when shown as active, else its compact slot.
    private func iconCenter(_ tab: RootTab) -> CGPoint {
        let y = rowHeight / 2
        if tab == shown { return CGPoint(x: Spec.capsulePadding + Spec.button / 2, y: y) }
        let slot = slots.firstIndex(of: tab) ?? 0
        let x = compactX + Spec.capsulePadding + Spec.button / 2 + CGFloat(slot) * (Spec.button + Spec.compactSpacing)
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        Group {
            if !keyboardVisible {
                dockBody
                    .padding(.horizontal, Spec.screenInset)
                    .padding(.bottom, Spec.bottomInset)
                    .frame(maxWidth: .infinity)
                    .dynamicTypeSize(...Spec.maxDynamicType)
            }
        }
        .onChange(of: selectedTab) { _, new in
            var next = slots
            if let i = next.firstIndex(of: new) { next[i] = shown }
            if reduceMotion {
                // Reduce Motion: the dock changes state in one frame; nothing travels.
                withTransaction(Transaction(animation: nil)) {
                    visualTab = new
                    compactSlots = next
                    litTab = nil
                    circleStart = nil
                }
                return
            }
            let moving = Date().timeIntervalSince(lastChange) < 0.3
            lastChange = Date()
            if moving {
                // Mid-burst the capsules are still travelling, so a jump to the tapped slot's target position
                // could land outside where the capsule is drawn. Retarget everything from where it is instead.
                withAnimation(Spec.spring) {
                    visualTab = new
                    compactSlots = next
                    circleStart = nil
                    litTab = nil
                }
                return
            }
            // Frame 1 (not animated): the circle lights up behind the tapped icon where it is.
            withTransaction(Transaction(animation: nil)) {
                circleStart = iconCenter(new)
                litTab = new
            }
            // Then one spring: icon + circle travel into the active capsule, the previous icon drops into the slot
            // just vacated. A later tap retargets from wherever things are; nothing queues.
            DispatchQueue.main.async {
                guard selectedTab == new else { return }
                withAnimation(Spec.spring) {
                    visualTab = new
                    compactSlots = next
                    circleStart = nil
                }
                litTab = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
    }

    private var dockBody: some View {
        ZStack(alignment: .topLeading) {
            // Structure: two charcoal capsules and the lime circle.
            Group {
                Capsule(style: .continuous)
                    .fill(Spec.charcoal)
                    .frame(width: activeW, height: rowHeight)
                Capsule(style: .continuous)
                    .fill(Spec.charcoal)
                    .frame(width: compactWidth, height: rowHeight)
                    .offset(x: compactX)
            }
            .compositingGroup()
            .shadow(color: Spec.shadowColor, radius: Spec.shadowRadius, y: Spec.shadowY)
            .accessibilityHidden(true)
            Circle()
                .fill(Spec.lime)
                .frame(width: Spec.button, height: Spec.button)
                .offset(x: (circleStart ?? iconCenter(shown)).x - Spec.button / 2,
                        y: (circleStart ?? iconCenter(shown)).y - Spec.button / 2)
                .accessibilityHidden(true)

            // The rest of the active capsule (its title) also reselects, as the capsule is one control visually.
            Color.clear
                .frame(width: activeW - Spec.capsulePadding - Spec.button, height: rowHeight)
                .contentShape(Rectangle())
                .offset(x: Spec.capsulePadding + Spec.button)
                .onTapGesture { onReselect(selectedTab) }
                .accessibilityHidden(true)

            // One persistent button per tab; it travels with its icon.
            ForEach(Self.order, id: \.self) { tab in
                tabButton(tab)
            }

            // The active title: replaced in one frame (never two, never a stale one, never an empty capsule).
            Text(shown.dockTitle)
                .font(.system(size: Spec.titleSize, weight: Spec.titleWeight))
                .foregroundStyle(Spec.ivory)
                .lineLimit(1)
                .minimumScaleFactor(Spec.titleMinimumScale)
                .frame(width: titleWidths[shown] ?? 60, height: rowHeight, alignment: .leading)
                // Drawn over the icons on the capsule colour: a travelling icon slides under the title instead of
                // crossing the text.
                // (button-high, so it stays inside the capsule's rounded end)
                .background(Spec.charcoal.frame(height: Spec.button))
                .offset(x: Spec.capsulePadding + Spec.button + Spec.iconTitleSpacing)
                .id(shown)
                .transition(.identity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

        }
        .frame(width: totalWidth, height: rowHeight, alignment: .topLeading)
        .background(alignment: .topLeading) { titleMeasurements }
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ tab: RootTab) -> some View {
        let onLime = litTab.map { $0 == tab } ?? (tab == shown)
        let center = iconCenter(tab)
        return Button {
            // Navigation reads the real selection, never the dock's (possibly mid-animation) visual state.
            if tab == selectedTab {
                onReselect(tab)
            } else {
                MMHaptics.selection()
                selectedTab = tab   // never animated here: the shell swaps pages in one frame
            }
        } label: {
            Image(systemName: tab.dockSymbol)
                .font(.system(size: Spec.iconSize, weight: Spec.iconWeight))
                .foregroundStyle(onLime ? Spec.charcoal : Spec.ivory)
                .frame(width: Spec.button, height: Spec.button)
                .contentShape(Circle())
        }
        .buttonStyle(MMPillDockPressStyle())
        .offset(x: center.x - Spec.button / 2, y: center.y - Spec.button / 2)
        .modifier(DockItemAccessibility(tab: tab, isSelected: tab == selectedTab))
    }

    /// Invisible copies of the three titles, measured at the current text size.
    private var titleMeasurements: some View {
        ZStack {
            ForEach(Self.order, id: \.self) { tab in
                Text(tab.dockTitle)
                    .font(.system(size: Spec.titleSize, weight: Spec.titleWeight))
                    .lineLimit(1)
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { w in
                        // Capped so the largest text sizes never push the dock off screen (the title scales down).
                        titleWidths[tab] = min(ceil(w), 120)
                    }
            }
        }
        .hidden()
        .accessibilityHidden(true)
    }
}

/// Labels, identifiers, traits and a fixed Proof → Reports → Account reading order, whatever the visual order.
private struct DockItemAccessibility: ViewModifier {
    let tab: RootTab
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(tab.dockTitle)
            .accessibilityIdentifier("tab.\(tab.dockIdentifier)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
            .accessibilitySortPriority(Double(3 - tab.dockIndex))
            .accessibilityShowsLargeContentViewer {
                Image(systemName: tab.dockSymbol)
                Text(tab.dockTitle)
            }
    }
}

extension RootTab {
    var dockTitle: String {
        switch self {
        case .vaults: "Proof"
        case .exports: "Reports"
        case .account: "Account"
        }
    }

    var dockIdentifier: String {
        switch self {
        case .vaults: "proof"
        case .exports: "reports"
        case .account: "account"
        }
    }

    /// The app's existing tab glyphs (filled: they read better inside the lime circle and on charcoal).
    var dockSymbol: String {
        switch self {
        case .vaults: "house.fill"
        case .exports: "doc.text.fill"
        case .account: "person.fill"
        }
    }
}

private struct MMPillDockPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : MMMotion.press, value: configuration.isPressed)
    }
}
