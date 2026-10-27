//
//  ScreenSnapshotTests.swift
//  movemorkTests
//
//  @file The shared screen-snapshot harness: the devices (Pro phone, small phone, largest text size), the
//        strategy, and hosting a screen as the app does. Each area's goldens live in its own suite
//        (Auth, Flow, RentalRecord, Maintenance…); the locked core is in VisualSnapshotTests.
//  @domain design-system
//  @see [[MMSystem.swift]]
//
//  Re-record after an approved change: delete the PNG under __Snapshots__ and run twice.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import MoveMark

/// Shared by every screen snapshot suite: the devices, the strategy, and hosting a screen as the app does.
@MainActor
enum ScreenSnapshot {
    static let pro = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 402, height: 874),
        traits: UITraitCollection(traitsFrom: [.init(displayScale: 3), .init(userInterfaceStyle: .light)])
    )
    static let small = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0),
        size: CGSize(width: 375, height: 667),
        traits: UITraitCollection(traitsFrom: [.init(displayScale: 2), .init(userInterfaceStyle: .light)])
    )
    static let proAX = ViewImageConfig(
        safeArea: pro.safeArea,
        size: pro.size,
        traits: UITraitCollection(traitsFrom: [pro.traits, .init(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)])
    )
    static let allDevices: [(String, ViewImageConfig)] = [("pro", pro), ("small", small), ("ax3", proAX)]
    static let strategy: (ViewImageConfig) -> Snapshotting<UIViewController, UIImage> = {
        .image(on: $0, precision: 0.995, perceptualPrecision: 0.98)
    }

    /// Hosts a screen the way the app does: in a NavigationStack, stores in the environment. Note: iOS 26
    /// navigation-bar titles and items don't render reliably in these window-less snapshots; check bars live.
    static func host<V: View>(_ view: V, inNavigation: Bool = true) -> UIViewController {
        let content = Group { if inNavigation { NavigationStack { view } } else { view } }
            .environment(SessionManager())
            .environment(PropertyStore())
            .environment(SubscriptionManager())
        return UIHostingController(rootView: content)
    }
}

extension XCTestCase {
    /// Snapshots a screen on the given devices (default: the Pro phone only).
    @MainActor
    func assertScreen<V: View>(_ view: V, devices: [(String, ViewImageConfig)] = [("pro", ScreenSnapshot.pro)],
                               inNavigation: Bool = true, file: StaticString = #filePath,
                               testName: String = #function, line: UInt = #line) {
        for (name, config) in devices {
            assertSnapshot(of: ScreenSnapshot.host(view, inNavigation: inNavigation), as: ScreenSnapshot.strategy(config),
                           named: name, file: file, testName: testName, line: line)
        }
    }
}
