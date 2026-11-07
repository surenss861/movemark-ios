//
//  MMRootTabHost.swift
//  movemork
//
//  The root-tab container shared by the signed-in shell and the DEBUG tabs fixture (so the fixture records the
//  production switching code, not a copy of it).
//
//  - Every visited page stays mounted (NavigationStack path, scroll position and loaded data survive), and the
//    shell and floating dock never remount on a tab change.
//  - Exactly one page is visible. A switch hides the old page and shows the new one in the same frame, with
//    animations disabled for that change: pages never crossfade, so the previous page is never superimposed on
//    the new one and two titles are never on screen together.
//  - The dock owns its own animation (scoped to the dock); the selection itself is never animated.
//  - The only page motion is the new page's content region, driven by ``MMTabEntrance`` (see
//    MMTabContentTransition.swift). A switch inside ``MMMotion/tabContentInterruptWindow`` of the previous one
//    lands instantly, so five rapid taps settle on the last tab with no queued or half-resolved pages.
//

import SwiftUI
import Observation

/// Selection and per-page entrance state for the root tabs.
@Observable
final class MMRootTabSwitcher {
    private(set) var selected: RootTab
    /// Pages mounted so far; they stay mounted.
    private(set) var visited: Set<RootTab>
    /// The latest entrance request per page; a page only reacts when its own value changes.
    private(set) var entrances: [RootTab: MMTabEntrance] = [:]

    @ObservationIgnored private var token = 0
    @ObservationIgnored private var lastSwitch: ContinuousClock.Instant?

    init(initial: RootTab = .vaults) {
        selected = initial
        visited = [initial]
    }

    /// Shows `tab` now. Returns false when it was already selected (the caller handles reselect).
    @discardableResult
    func select(_ tab: RootTab, variant: MMNavVariant = .current, reduceMotion: Bool) -> Bool {
        guard tab != selected else { return false }
        let now = ContinuousClock.now
        let interrupting = lastSwitch.map { now - $0 < MMMotion.tabContentInterruptWindow } ?? false
        // A first visit mounts the page already in place: there is nothing on screen yet to move.
        let firstVisit = !visited.contains(tab)
        let style: MMTabEntrance.Style = interrupting || firstVisit
            ? .none
            : MMTabEntrance.style(for: variant, from: selected, to: tab, reduceMotion: reduceMotion)
        token += 1
        // The swap itself is never animated, whatever transaction the caller is in. (Not `disablesAnimations`:
        // that would also stop the dock's own scoped `.animation(_:value:)`.)
        withTransaction(Transaction(animation: nil)) {
            visited.insert(tab)
            entrances[tab] = MMTabEntrance(token: token, style: style)
            selected = tab
        }
        lastSwitch = now
        return true
    }
}

struct MMRootTabHost<Page: View, Dock: View>: View {
    let switcher: MMRootTabSwitcher
    var scrollToTopTokens: [RootTab: Int] = [:]
    var showsDock: Bool = true
    @ViewBuilder var page: (RootTab) -> Page
    @ViewBuilder var dock: () -> Dock

    static var tabs: [RootTab] { [.vaults, .exports, .account] }

    var body: some View {
        ZStack {
            ForEach(Self.tabs, id: \.self) { tab in
                if switcher.visited.contains(tab) {
                    layer(tab)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.mmRootTabBarVisible, showsDock)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsDock {
                dock()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsDock)
    }

    /// One page. Only the selected page is visible, hit-testable and in the accessibility tree.
    private func layer(_ tab: RootTab) -> some View {
        let isSelected = tab == switcher.selected
        return page(tab)
            .environment(\.mmScrollToTopToken, scrollToTopTokens[tab, default: 0])
            .environment(\.mmRootTabIsActive, isSelected)
            .environment(\.mmTabEntrance, switcher.entrances[tab] ?? .rest)
            .opacity(isSelected ? 1 : 0)
            .zIndex(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            // Does not reach inside a NavigationStack on its own: each stack root also carries
            // .mmRootTabAccessibilityGate().
            .accessibilityHidden(!isSelected)
            .transition(.identity)
            // Visibility never animates, even if a surrounding transaction does (e.g. the dock appearing as
            // a programmatic switch pops a pushed screen): no frame ever holds two pages.
            .transaction(value: isSelected) { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }
}

// MARK: - Accessibility gate (kept-alive pages)

extension View {
    /// Put on a root tab's NavigationStack root content (and on pushed screens that should follow it). While the
    /// tab is kept alive behind another one, this content leaves the accessibility tree.
    ///
    /// Needed because `.accessibilityHidden` on the page in MMRootTabHost does not reach into a NavigationStack's
    /// hosted content: UI tests (and so VoiceOver) still found a hidden page's title. Applied inside the stack it
    /// works for the root. Known gap: a screen pushed inside a kept-alive stack (and its navigation bar) can stay
    /// in the tree; see RootTabNavigationUITests.test04.
    func mmRootTabAccessibilityGate() -> some View {
        modifier(MMRootTabAccessibilityGateModifier())
    }
}

private struct MMRootTabAccessibilityGateModifier: ViewModifier {
    @Environment(\.mmRootTabIsActive) private var isActive

    func body(content: Content) -> some View {
        content.accessibilityHidden(!isActive)
    }
}
