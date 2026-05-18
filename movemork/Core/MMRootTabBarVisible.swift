//
//  MMRootTabBarVisible.swift
//  movemork
//
//  When false, the root tab bar is hidden (workspace / task flows). Scroll content can use a tighter bottom tail.
//

import SwiftUI

private struct MMRootTabBarVisibleKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// True only on Proof / Reports / Account at root — tab bar is on-screen and reserves layout height.
    var mmRootTabBarVisible: Bool {
        get { self[MMRootTabBarVisibleKey.self] }
        set { self[MMRootTabBarVisibleKey.self] = newValue }
    }
}
