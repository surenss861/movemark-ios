//
//  VaultScreenshotUITests.swift
//  movemorkUITests
//
//  Screenshots of the Proof (Vault) screen as a real account sees it, on a simulator or a physical device.
//  Opt-in: signs in with a disposable account passed through the environment (never stored here):
//    TEST_RUNNER_MM_VAULT_EMAIL=… TEST_RUNNER_MM_VAULT_PASSWORD=… xcodebuild test -configuration Release \
//      -only-testing:movemorkUITests/VaultScreenshotUITests …
//  Screenshots are attached to the result bundle (kept always).
//

import XCTest

final class VaultScreenshotUITests: XCTestCase {
    func testVaultAsASignedInRenterSeesIt() throws {
        let app = try signedIn()
        sleep(5)  // let the evidence thumbnail load
        attach(app, "vault-top")
        app.swipeUp()
        sleep(2)
        attach(app, "vault-scrolled")
    }

    /// The capture journey's screens the simulator can show (no camera here): the room brief right after
    /// tapping the Vault's capture action, and what "Take photos" opens.
    func testCaptureEntryAsASignedInRenterSeesIt() throws {
        let app = try signedIn()
        let capture = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Capture '")).firstMatch
        XCTAssertTrue(capture.waitForExistence(timeout: 20))
        capture.tap()
        sleep(3)
        attach(app, "room-brief")
        let take = app.buttons["Take photos"].firstMatch
        if take.waitForExistence(timeout: 8) {
            take.tap()
            sleep(3)
            attach(app, "after-take-photos")
        }
    }

    /// A room right after its proof was saved: opened from the Vault's recent evidence.
    func testSavedRoomAsASignedInRenterSeesIt() throws {
        let app = try signedIn()
        let room = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", env("MM_SHOT_ROOM") ?? "Living Room")).firstMatch
        XCTAssertTrue(room.waitForExistence(timeout: 20))
        room.tap()
        sleep(5)
        attach(app, "saved-room")
        app.swipeUp()
        sleep(2)
        attach(app, "saved-room-scrolled")
    }

    /// On a physical device: a real capture of three photos, the live camera after the first, the review
    /// step, then the receipt after a real save, its next-room navigation and Back.
    func testRealCaptureOnDevice() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("needs a camera")
        #else
        let app = try signedIn()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let capture = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Capture '")).firstMatch
        XCTAssertTrue(capture.waitForExistence(timeout: 20))
        capture.tap()
        sleep(2)
        attach(app, "1-room-brief")

        for shot in 1...3 {
            let take = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Take photos'")).firstMatch
            XCTAssertTrue(take.waitForExistence(timeout: 10), "Take photos (shot \(shot))")
            take.tap()
            if springboard.buttons["Allow"].waitForExistence(timeout: 3) { springboard.buttons["Allow"].tap() }
            let shutter = app.buttons["camera.shutter"]
            XCTAssertTrue(shutter.waitForExistence(timeout: 15), "camera (shot \(shot))")
            sleep(2)  // let exposure settle
            if shot == 2 { attach(app, "2-live-camera-after-one-photo") }
            shutter.tap()
            let use = app.buttons["camera.use"]
            XCTAssertTrue(use.waitForExistence(timeout: 10))
            if shot == 2 { attach(app, "3-camera-review") }
            use.tap()
            sleep(2)
            if shot == 3 { attach(app, "4-room-with-pending-photos") }
        }

        let save = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Save proof'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let saved = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'PROOF'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 90), "receipt after save")
        sleep(5)  // the saved photo
        attach(app, "5-receipt")
        app.swipeUp()
        sleep(1)
        attach(app, "6-receipt-scrolled")

        let next = app.buttons["Continue to next room"]
        if next.waitForExistence(timeout: 5) {
            next.tap()
            sleep(3)
            attach(app, "7-next-room")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(3)
            attach(app, "8-after-back")
        }
        #endif
    }

    private func env(_ key: String) -> String? { ProcessInfo.processInfo.environment[key] }

    private func signedIn() throws -> XCUIApplication {
        guard let email = env("MM_VAULT_EMAIL"), let password = env("MM_VAULT_PASSWORD") else {
            throw XCTSkip("set TEST_RUNNER_MM_VAULT_EMAIL and TEST_RUNNER_MM_VAULT_PASSWORD")
        }
        let app = XCUIApplication()
        app.launch()
        let signIn = app.buttons["welcome.signIn"]
        // Only ever act as the disposable account: a device already signed in (someone's real account) is
        // refused, never used.
        guard signIn.waitForExistence(timeout: 12) else {
            XCTFail("The app is already signed in to an account; sign out first. These tests only run as the disposable account.")
            throw XCTSkip("already signed in")
        }
        do {
            signIn.tap()
            let emailField = app.textFields["auth.email"]
            XCTAssertTrue(emailField.waitForExistence(timeout: 8))
            emailField.tap()
            emailField.typeText(email)
            let passwordField = app.secureTextFields["auth.password"]
            passwordField.tap()
            passwordField.typeText(password)
            app.buttons["auth.primaryAction"].tap()
            XCTAssertTrue(app.staticTexts["YOUR PROOF"].waitForExistence(timeout: 40))
            app.terminate()
            app.launch()
        }
        XCTAssertTrue(app.staticTexts["YOUR PROOF"].waitForExistence(timeout: 40), "Vault did not appear")
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
