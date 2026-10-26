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

        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Take photos'")).firstMatch.tap()
        if springboard.buttons["Allow"].waitForExistence(timeout: 3) { springboard.buttons["Allow"].tap() }
        let shutter = app.buttons["camera.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 15), "camera")
        sleep(2)
        attach(app, "2-camera-before-first-shot")
        // Continuous: four shots without leaving the camera.
        for shot in 1...4 {
            shutter.tap()
            let count = app.staticTexts["camera.count"]
            XCTAssertTrue(count.waitForExistence(timeout: 10))
            let expected = shot == 1 ? "1 photo captured" : "\(shot) photos captured"
            XCTAssertTrue(NSPredicate(format: "label == %@", expected).evaluate(with: count) ||
                          app.staticTexts[expected].waitForExistence(timeout: 10), "count after shot \(shot)")
            if shot == 1 { attach(app, "3-camera-after-one-shot") }
            sleep(1)
        }
        attach(app, "4-camera-after-four-shots")

        app.buttons["camera.thumbnail"].tap()  // review in the room
        sleep(2)
        attach(app, "5-room-with-four-pending")
        let remove = app.buttons["Remove photo 4"]
        if remove.waitForExistence(timeout: 5) { remove.tap(); sleep(1) }
        attach(app, "6-room-after-removing-one")

        let save = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Save proof'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let saved = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'PROOF'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 90), "receipt after save")
        sleep(5)
        attach(app, "7-receipt")
        let next = app.buttons["Continue to next room"]
        if next.waitForExistence(timeout: 5) {
            next.tap()
            sleep(3)
            attach(app, "8-next-room")
        }
        #endif
    }

    /// The root dock on all three root surfaces, at rest and scrolled to the bottom.
    func testRootTabsWithTheDock() throws {
        let app = try signedIn()
        sleep(3)
        attach(app, "tab-proof")
        scrollToBottom(app)
        attach(app, "tab-proof-bottom")
        for title in ["Reports", "Account"] {
            app.buttons[title].firstMatch.tap()
            sleep(3)
            attach(app, "tab-\(title.lowercased())")
            scrollToBottom(app)
            attach(app, "tab-\(title.lowercased())-bottom")
        }
    }

    /// Swipes until the scroll settles at its end (momentum included), so the shot shows the real bottom.
    private func scrollToBottom(_ app: XCUIApplication) {
        for _ in 0..<6 { app.swipeUp() }
        sleep(3)
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
        if !signIn.waitForExistence(timeout: 12) {
            // Already signed in (someone's real account): never used. Signed out first only when the run says so.
            guard env("MM_ALLOW_SIGN_OUT") == "1" else {
                XCTFail("The app is already signed in to an account; sign out first. These tests only run as the disposable account.")
                throw XCTSkip("already signed in")
            }
            app.buttons["Account"].firstMatch.tap()
            let signOut = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sign out'")).firstMatch
            for _ in 0..<6 where !signOut.isHittable { app.swipeUp() }
            signOut.tap()
            XCTAssertTrue(signIn.waitForExistence(timeout: 20), "signed out")
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
