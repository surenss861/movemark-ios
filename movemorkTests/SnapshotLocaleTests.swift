//
//  SnapshotLocaleTests.swift
//  movemorkTests
//
//  Goldens must not depend on the simulator's region. The scheme's Test action pins the test host to
//  en_US / America/Toronto (`-AppleLocale en_US`, `-AppleLanguages (en-US)`, `TZ`), and the snapshot harness
//  pins SwiftUI's locale, calendar and time zone (`snapshotLocale()`). If these fail, the run is not using
//  the pinned settings and snapshot failures from it say nothing about the UI.
//

import Foundation
import Testing
@testable import MoveMark

@MainActor
struct SnapshotLocaleTests {
    private let oct19 = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "America/Toronto"),
                                       year: 2025, month: 10, day: 19, hour: 14, minute: 5).date!

    @Test func testHostIsPinnedToUSEnglishAndToronto() {
        #expect(Locale.current.identifier == "en_US")
        #expect(TimeZone.current.identifier == "America/Toronto")
    }

    @Test func appSideFormattingMatchesTheGoldens() {
        // en_CA would give "Oct. 19" / "2:05 p.m." / "2025-10-19".
        #expect(oct19.formatted(.dateTime.month(.abbreviated).day()) == "Oct 19")
        #expect(oct19.formatted(date: .omitted, time: .shortened).replacingOccurrences(of: "\u{202F}", with: " ") == "2:05 PM")
        #expect(oct19.formatted(date: .numeric, time: .omitted) == "10/19/2025")
    }

    @Test func harnessEnvironmentIsGregorianUSToronto() {
        #expect(ScreenSnapshot.locale.identifier == "en_US")
        #expect(ScreenSnapshot.calendar.identifier == .gregorian)
        #expect(ScreenSnapshot.calendar.timeZone.identifier == "America/Toronto")
    }
}
