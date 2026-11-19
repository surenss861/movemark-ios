//
//  DeviceNounTests.swift
//  movemorkTests
//
//  Copy about photos kept on the device names the device it runs on: iPad QA (2026-11-18) found
//  "Saved on this iPhone · not uploaded yet" on an iPad. iPhone copy must stay word for word.
//

import Testing
@testable import MoveMark

@MainActor
struct DeviceNounTests {
    @Test func namesTheDevice() {
        #expect(MMDeviceNoun.noun(isPad: false) == "iPhone")
        #expect(MMDeviceNoun.noun(isPad: true) == "iPad")
    }

    @Test func iPhoneCopyIsUnchanged() {
        // The test host is an iPhone simulator in CI-equivalent runs; on an iPad host this reads "iPad".
        let expected = MMDeviceNoun.current == "iPad" ? "Saved on this iPad · not uploaded yet" : "Saved on this iPhone · not uploaded yet"
        #expect(MMEvidenceSyncState.savedLocally.message == expected)
    }
}
