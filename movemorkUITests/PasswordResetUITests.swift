//
//  PasswordResetUITests.swift
//  movemorkUITests
//
//  Self-serve password reset end to end on the DEBUG fixture (`-MMPasswordResetFixture`): sign in →
//  "Forgot password?" → send → neutral confirmation with a resend cooldown → the reset link opened as a
//  deep link → new password → sign in. The fixture answers the two Neon Auth calls locally, so no request
//  leaves the simulator and no email is sent.
//

import XCTest

final class PasswordResetUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRequestConfirmationDeepLinkNewPassword() throws {
        let app = launchSignedOut()

        app.buttons["welcome.signIn"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 5))

        let forgot = app.buttons["auth.forgotPassword"]
        XCTAssertTrue(forgot.waitForExistence(timeout: 3))
        forgot.tap()
        XCTAssertTrue(app.staticTexts["Reset your password"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.secureTextFields.count, 0, "The request step asks for the email only")

        // An unusable address stays on the form.
        let email = app.textFields["auth.email"]
        email.tap()
        email.typeText("alex")
        app.buttons["auth.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["Enter a valid email."].waitForExistence(timeout: 3))

        email.typeText("@example.com")
        app.buttons["auth.primaryAction"].tap()

        // Neutral confirmation: never says whether the address has an account.
        XCTAssertTrue(app.staticTexts["Check your email"].waitForExistence(timeout: 5))
        let sent = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'If alex@example.com has a MoveMark account'")).firstMatch
        XCTAssertTrue(sent.exists)
        let resend = app.buttons["auth.resendReset"]
        XCTAssertTrue(resend.exists)
        XCTAssertFalse(resend.isEnabled, "Resend waits out the cooldown")
        XCTAssertTrue(resend.label.hasPrefix("Resend in"))

        // The emailed link, as the reset page's "Open MoveMark" button hands it over.
        app.open(URL(string: "movemark://reset-password?token=fixture-token")!)
        XCTAssertTrue(app.staticTexts["Choose a new password"].waitForExistence(timeout: 8))

        let newPassword = app.secureTextFields["passwordReset.password"]
        newPassword.tap()
        newPassword.typeText("correct-horse-9")
        let confirm = app.secureTextFields["passwordReset.confirm"]
        confirm.tap()
        confirm.typeText("correct-horse-9")
        app.buttons["passwordReset.save"].tap()

        XCTAssertTrue(app.staticTexts["Password updated"].waitForExistence(timeout: 5))
        app.buttons["passwordReset.done"].tap()

        // Success goes on to sign in.
        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["auth.primaryAction"].exists)
    }

    /// A link Neon Auth already refused (the page forwards `error=INVALID_TOKEN`), and a token refused on
    /// save, both end on "Link expired" with the way to request a new one.
    @MainActor
    func testExpiredLinkLeadsToANewRequest() throws {
        let app = launchSignedOut()

        app.open(URL(string: "movemark://reset-password?error=INVALID_TOKEN")!)
        XCTAssertTrue(app.staticTexts["Link expired"].waitForExistence(timeout: 8))
        app.buttons["passwordReset.requestNew"].tap()
        XCTAssertTrue(app.staticTexts["Reset your password"].waitForExistence(timeout: 5))

        app.open(URL(string: "movemark://reset-password#token=expired")!)
        XCTAssertTrue(app.staticTexts["Choose a new password"].waitForExistence(timeout: 8))
        let newPassword = app.secureTextFields["passwordReset.password"]
        newPassword.tap()
        newPassword.typeText("correct-horse-9")
        let confirm = app.secureTextFields["passwordReset.confirm"]
        confirm.tap()
        confirm.typeText("correct-horse-9")
        app.buttons["passwordReset.save"].tap()
        XCTAssertTrue(app.staticTexts["Link expired"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["passwordReset.requestNew"].exists)
    }

    // MARK: - Helpers

    /// Launches on the fixture and makes sure Welcome is showing (signs out if an earlier run left a session).
    private func launchSignedOut() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-MMPasswordResetFixture", "-UIPreferredMotionReduced", "1"]
        app.launch()
        if !app.buttons["welcome.signIn"].waitForExistence(timeout: 15) {
            app.buttons["Account"].firstMatch.tap()
            let signOut = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sign out'")).firstMatch
            for _ in 0..<6 where !signOut.isHittable { app.swipeUp() }
            signOut.tap()
        }
        XCTAssertTrue(app.buttons["welcome.signIn"].waitForExistence(timeout: 20))
        return app
    }
}
