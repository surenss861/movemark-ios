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

    /// One set of empty stores for every hosted screen. They outlive the hosting controllers on purpose: a
    /// store created per host was released from inside SwiftUI's teardown of an earlier snapshot, and its
    /// main-actor deinit crashed the test host in the Swift runtime (TaskLocal scope, "pointer being freed
    /// was not allocated") a few tests later. The screens only read these stores.
    static let sessionManager = SessionManager()
    static let propertyStore = PropertyStore()
    static let subscriptionManager = SubscriptionManager()

    /// Goldens are recorded in one locale, calendar and time zone, whatever the simulator is set to: an
    /// en_CA region rendered the compact DatePicker as `2025-10-19` instead of `Oct 19, 2025`. SwiftUI
    /// output (DatePicker, `Text(date, format:)`) follows this environment; strings the app formats itself
    /// with `Locale.current` follow the test host's `-AppleLocale en_US` and `TZ` (scheme Test action),
    /// which `SnapshotLocaleTests` checks.
    static let locale = Locale(identifier: "en_US")
    static let timeZone = TimeZone(identifier: "America/Toronto")!
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        return calendar
    }()

    /// Hosts a screen the way the app does: in a NavigationStack, stores in the environment. Note: iOS 26
    /// navigation-bar titles and items don't render reliably in these window-less snapshots; check bars live.
    static func host<V: View>(_ view: V, inNavigation: Bool = true) -> UIViewController {
        let content = Group { if inNavigation { NavigationStack { view } } else { view } }
            .environment(sessionManager)
            .environment(propertyStore)
            .environment(subscriptionManager)
            .snapshotLocale()
        return UIHostingController(rootView: content)
    }
}

extension View {
    /// The fixed locale, calendar and time zone every golden is recorded in (see `ScreenSnapshot.locale`).
    @MainActor
    func snapshotLocale() -> some View {
        environment(\.locale, ScreenSnapshot.locale)
            .environment(\.calendar, ScreenSnapshot.calendar)
            .environment(\.timeZone, ScreenSnapshot.timeZone)
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
