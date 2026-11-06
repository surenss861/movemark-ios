//
//  SocialSignInDeviceUITests.swift
//  movemorkUITests
//
//  Device QA for the browser sign-in sheet, up to the provider's own page. It never enters credentials or advances a
//  sign-in: real accounts are for a person to use. Records what each sheet shows.
//  Run on a phone with a Debug build pointed at the target environment.
//

import XCTest

final class SocialSignInDeviceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-MoveMarkSocialLive", "YES"]
        app.launch()
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Opens a provider's sheet and records it. Touches nothing inside the sheet.
    private func openSheet(_ identifier: String, name: String) -> XCUIApplication {
        let button = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 20), "\(identifier) missing: is the app signed out?")
        attach("\(name)-1-welcome")
        button.tap()
        let sheet = XCUIApplication(bundleIdentifier: "com.apple.SafariViewService")
        XCTAssertTrue(sheet.wait(for: .runningForeground, timeout: 15) || sheet.webViews.firstMatch.waitForExistence(timeout: 5),
                      "the system sign-in sheet did not open")
        Thread.sleep(forTimeInterval: 7)
        attach("\(name)-2-provider-page")
        return sheet
    }

    /// Google's error page has nothing to sign in to, so closing the sheet is safe. The sheet must actually be gone
    /// before Welcome is checked: Welcome's elements still "exist" behind an open sheet.
    func testGoogleSheetOpensAndCancelIsSilent() {
        let sheet = openSheet("welcome.social.google", name: "google")
        let close = sheet.buttons["Cancel"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10), "no close button on the sheet")
        close.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "the sheet is still in front")
        Thread.sleep(forTimeInterval: 1)
        attach("google-3-after-cancel")
        XCTAssertTrue(app.descendants(matching: .any)["welcome.primaryCTA"].isHittable, "Welcome is not in front")
        XCTAssertFalse(app.staticTexts["Sign-in didn’t finish. Try again."].exists, "a cancel must stay silent")
    }

    /// Apple's sheet signs in with the phone's real Apple Account, and its first button can advance to Face ID. Automation
    /// must never touch it: open, record, then end the app, which ends the attempt.
    func testAppleSheetOpensWithoutTouchingIt() {
        _ = openSheet("welcome.social.apple", name: "apple")
        app.terminate()
    }
}
