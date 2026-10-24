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
        let env = ProcessInfo.processInfo.environment
        guard let email = env["MM_VAULT_EMAIL"], let password = env["MM_VAULT_PASSWORD"] else {
            throw XCTSkip("set TEST_RUNNER_MM_VAULT_EMAIL and TEST_RUNNER_MM_VAULT_PASSWORD")
        }
        let app = XCUIApplication()
        app.launch()

        let signIn = app.buttons["welcome.signIn"]
        if signIn.waitForExistence(timeout: 12) {
            signIn.tap()
            let emailField = app.textFields["auth.email"]
            XCTAssertTrue(emailField.waitForExistence(timeout: 8))
            emailField.tap()
            emailField.typeText(email)
            let passwordField = app.secureTextFields["auth.password"]
            passwordField.tap()
            passwordField.typeText(password)
            app.buttons["auth.primaryAction"].tap()
            // iOS then offers to save the password from a system process the test can't reach: relaunch
            // instead (the session survives in the keychain; the prompt doesn't).
            XCTAssertTrue(app.staticTexts["YOUR PROOF"].waitForExistence(timeout: 40), "sign-in did not reach the Vault")
            app.terminate()
            app.launch()
        }

        XCTAssertTrue(app.staticTexts["YOUR PROOF"].waitForExistence(timeout: 40), "Vault did not appear")
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

    private func env(_ key: String) -> String? { ProcessInfo.processInfo.environment[key] }

    private func signedIn() throws -> XCUIApplication {
        guard let email = env("MM_VAULT_EMAIL"), let password = env("MM_VAULT_PASSWORD") else {
            throw XCTSkip("set TEST_RUNNER_MM_VAULT_EMAIL and TEST_RUNNER_MM_VAULT_PASSWORD")
        }
        let app = XCUIApplication()
        app.launch()
        let signIn = app.buttons["welcome.signIn"]
        if signIn.waitForExistence(timeout: 12) {
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
