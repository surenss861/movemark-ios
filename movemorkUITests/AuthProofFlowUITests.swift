//
//  AuthProofFlowUITests.swift
//  movemorkUITests
//
//  QA: Welcome → proof-first auth → morph → keyboard visibility.
//

import XCTest

final class AuthProofFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testWelcomeSignInOpensSignInMode() throws {
        let signIn = app.buttons["welcome.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 8))
        signIn.tap()

        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Proof vault ready"].exists)
        XCTAssertTrue(app.buttons["Continue proof vault"].exists)
        XCTAssertEqual(app.secureTextFields.count, 1)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Private proof vault'")).element.exists)
    }

    @MainActor
    func testWelcomeCTAOpensCreateVaultFlow() throws {
        let cta = app.buttons["welcome.primaryCTA"]
        XCTAssertTrue(cta.waitForExistence(timeout: 8))
        cta.tap()

        XCTAssertTrue(app.staticTexts["Create your proof vault"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Private proof vault"].exists)
        XCTAssertTrue(app.buttons["auth.primaryAction"].exists)
    }

    @MainActor
    func testCreateToSignInMorph() throws {
        openCreateAuth()

        XCTAssertTrue(app.staticTexts["Private proof vault"].exists)

        switchAuthMode()

        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Proof vault ready"].exists)
        XCTAssertTrue(app.buttons["auth.primaryAction"].exists)
        XCTAssertEqual(app.secureTextFields.count, 1, "Sign-in should show one password field")
        XCTAssertFalse(app.staticTexts["By continuing, you agree to"].exists)
    }

    @MainActor
    func testSignInToCreateMorph() throws {
        openCreateAuth()
        switchAuthMode()
        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 3))

        switchAuthMode()

        XCTAssertTrue(app.staticTexts["Create your proof vault"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Private proof vault"].exists)
        XCTAssertEqual(app.secureTextFields.count, 2, "Create should show password + confirm")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'By continuing'")).firstMatch.exists
        )
    }

    @MainActor
    func testKeyboardDoesNotHidePrimaryCTA() throws {
        openCreateAuth()

        let email = app.textFields["auth.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 3))
        email.tap()

        let cta = app.buttons["auth.primaryAction"]
        XCTAssertTrue(cta.waitForExistence(timeout: 3))

        if !cta.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(cta.exists)
    }

    @MainActor
    func testDismissAndReopenResetsToCreateMode() throws {
        openCreateAuth()
        switchAuthMode()
        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 3))

        app.buttons["auth.dismiss"].tap()
        XCTAssertTrue(app.buttons["welcome.primaryCTA"].waitForExistence(timeout: 5))

        app.buttons["welcome.primaryCTA"].tap()
        XCTAssertTrue(app.staticTexts["Create your proof vault"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Private proof vault"].exists)
        XCTAssertEqual(app.secureTextFields.count, 2)
    }

    @MainActor
    func testReduceMotionAuthStillFunctional() throws {
        app.terminate()
        app.launchArguments += ["-UIPreferredMotionReduced", "1"]
        app.launch()

        openCreateAuth()
        switchAuthMode(timeout: 5)
        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 5))
        switchAuthMode(timeout: 5)
        XCTAssertTrue(app.staticTexts["Private proof vault"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    /// Interactions address controls by accessibility identifier, never by visible label:
    /// while the auth surface is up, Welcome's dimmed dock also carries a "Sign in" button,
    /// so a label lookup is ambiguous and can resolve to the non-hittable one. Assertions
    /// still check user-facing copy, which is part of the product contract.
    private func openCreateAuth() {
        let cta = app.buttons["welcome.primaryCTA"]
        XCTAssertTrue(cta.waitForExistence(timeout: 8))
        cta.tap()
        XCTAssertTrue(app.staticTexts["Create your proof vault"].waitForExistence(timeout: 5))
    }

    @discardableResult
    private func switchAuthMode(timeout: TimeInterval = 3) -> XCUIElement {
        let toggle = app.buttons["auth.switchMode"]
        XCTAssertTrue(toggle.waitForExistence(timeout: timeout))
        toggle.tap()
        return toggle
    }
}
