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

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
