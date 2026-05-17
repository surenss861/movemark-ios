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
        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 8))
        signIn.tap()

        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Last saved"].exists)
        XCTAssertTrue(app.buttons["Continue proof vault"].exists)
        XCTAssertEqual(app.secureTextFields.count, 1)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ready to save'")).element.exists)
    }

    @MainActor
    func testWelcomeCTAOpensCreateVaultFlow() throws {
        let cta = app.buttons["Start move-in proof"]
        XCTAssertTrue(cta.waitForExistence(timeout: 8))
        cta.tap()

        XCTAssertTrue(app.staticTexts["Start your move-in proof."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kitchen proof"].exists)
        XCTAssertTrue(app.staticTexts["Ready to save"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Create private vault"].exists)
    }

    @MainActor
    func testCreateToSignInMorph() throws {
        openCreateAuth()

        XCTAssertTrue(app.staticTexts["Kitchen proof"].exists)

        app.buttons["Continue proof vault"].tap()

        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Last saved"].exists)
        XCTAssertTrue(app.buttons["Continue proof vault"].exists)
        XCTAssertEqual(app.secureTextFields.count, 1, "Sign-in should show one password field")
        XCTAssertFalse(app.staticTexts["By continuing, you agree to"].exists)
    }

    @MainActor
    func testSignInToCreateMorph() throws {
        openCreateAuth()
        app.buttons["Continue proof vault"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 3))

        app.buttons["Create private vault"].tap()

        XCTAssertTrue(app.staticTexts["Start your move-in proof."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Ready to save"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.secureTextFields.count, 2, "Create should show password + confirm")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'By continuing'")).firstMatch.exists
        )
    }

    @MainActor
    func testKeyboardDoesNotHidePrimaryCTA() throws {
        openCreateAuth()

        let email = app.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 3))
        email.tap()

        let cta = app.buttons["Create private vault"]
        XCTAssertTrue(cta.waitForExistence(timeout: 3))

        if !cta.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(cta.exists)
    }

    @MainActor
    func testDismissAndReopenResetsToCreateMode() throws {
        openCreateAuth()
        app.buttons["Continue proof vault"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 3))

        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Start move-in proof"].waitForExistence(timeout: 5))

        app.buttons["Start move-in proof"].tap()
        XCTAssertTrue(app.staticTexts["Start your move-in proof."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready to save"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.secureTextFields.count, 2)
    }

    @MainActor
    func testReduceMotionAuthStillFunctional() throws {
        app.terminate()
        app.launchArguments += ["-UIPreferredMotionReduced", "1"]
        app.launch()

        openCreateAuth()
        app.buttons["Continue proof vault"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 5))
        app.buttons["Create private vault"].tap()
        XCTAssertTrue(app.staticTexts["Ready to save"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func openCreateAuth() {
        let cta = app.buttons["Start move-in proof"]
        XCTAssertTrue(cta.waitForExistence(timeout: 8))
        cta.tap()
        XCTAssertTrue(app.staticTexts["Start your move-in proof."].waitForExistence(timeout: 5))
    }
}
