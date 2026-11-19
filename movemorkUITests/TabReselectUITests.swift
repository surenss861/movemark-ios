//
//  TabReselectUITests.swift
//  movemorkUITests
//
//  Live check of root-tab behaviour and unsaved-changes sheets with a disposable QA account (credentials only
//  from TEST_RUNNER_MM_VAULT_EMAIL / TEST_RUNNER_MM_VAULT_PASSWORD; skipped without them):
//  - scroll position survives tab switches, and returning to Reports never passes back through its loading state;
//  - tapping the active dock item scrolls that page to its top;
//  - Edit name / Record an issue ask "Discard changes?" on Cancel and on swipe-down, and reopen afterwards.
//  Nothing is saved: every sheet is discarded.
//

import XCTest

final class TabReselectUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func test01_ScrollSurvivesTabsAndReselectScrollsToTop() throws {
        let app = try signedIn()

        // Proof: scroll down, note where the header sits.
        let proofHeader = app.staticTexts["YOUR PROOF"].firstMatch
        let proofTop = proofHeader.frame.minY
        app.swipeUp()
        sleep(1)
        let proofScrolled = proofHeader.frame.minY
        attach(app, "tabs-1-proof-scrolled")
        XCTAssertLessThan(proofScrolled, proofTop - 50, "Proof scrolled")

        // Reports: let it load, scroll a little.
        app.buttons["Reports"].firstMatch.tap()
        let reportsHeader = app.staticTexts["Your proof records"].firstMatch
        XCTAssertTrue(reportsHeader.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntilGone(app.staticTexts["Checking your records…"], timeout: 20), "Reports loaded")
        let reportsTop = reportsHeader.frame.minY
        drag(app, by: 0.25)
        let reportsScrolled = reportsHeader.frame.minY
        attach(app, "tabs-2-reports-scrolled")

        // Account and back to Reports: no loading flash, same scroll position.
        app.buttons["Account"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your account"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Reports"].firstMatch.tap()
        var sawLoading = false
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if app.staticTexts["Checking your records…"].exists { sawLoading = true }
            usleep(100_000)
        }
        attach(app, "tabs-3-reports-returned")
        XCTAssertFalse(sawLoading, "Returning to Reports showed its loading state")
        XCTAssertEqual(reportsHeader.frame.minY, reportsScrolled, accuracy: 2, "Reports kept its scroll")

        // Reports reselect: back to the top.
        app.buttons["Reports"].firstMatch.tap()
        sleep(1)
        attach(app, "tabs-4-reports-reselected")
        XCTAssertEqual(reportsHeader.frame.minY, reportsTop, accuracy: 2, "Reports scrolled to top")

        // Proof kept its scroll across two switches.
        app.buttons["Proof"].firstMatch.tap()
        sleep(1)
        attach(app, "tabs-5-proof-returned")
        XCTAssertEqual(proofHeader.frame.minY, proofScrolled, accuracy: 2, "Proof kept its scroll")

        // Proof reselect: back to the top.
        app.buttons["Proof"].firstMatch.tap()
        sleep(1)
        attach(app, "tabs-6-proof-reselected")
        XCTAssertEqual(proofHeader.frame.minY, proofTop, accuracy: 2, "Proof scrolled to top")

        // Account: scroll, reselect, top.
        app.buttons["Account"].firstMatch.tap()
        let accountHeader = app.staticTexts["Your account"].firstMatch
        XCTAssertTrue(accountHeader.waitForExistence(timeout: 5))
        let accountTop = accountHeader.frame.minY
        drag(app, by: 0.3)
        XCTAssertLessThan(accountHeader.frame.minY, accountTop - 30, "Account scrolled")
        app.buttons["Account"].firstMatch.tap()
        sleep(1)
        attach(app, "tabs-7-account-reselected")
        XCTAssertEqual(accountHeader.frame.minY, accountTop, accuracy: 2, "Account scrolled to top")
    }

    func test02_UnsavedSheetsAskBeforeDiscarding() throws {
        let app = try signedIn()

        // Account › Edit name.
        app.buttons["Account"].firstMatch.tap()
        let nameRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Name'")).firstMatch
        XCTAssertTrue(nameRow.waitForExistence(timeout: 10), "Name row")
        nameRow.tap()
        let field = app.textFields["Full name"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        dismissKeyboardTip(app)
        field.typeText(" QA")

        // Swipe down: blocked, asks.
        dismissSwipe(app)
        attach(app, "sheet-0-name-after-swipe")
        let discardTitle = app.staticTexts["Discard changes?"].firstMatch
        XCTAssertTrue(discardTitle.waitForExistence(timeout: 4), "swipe-down asks")
        attach(app, "sheet-1-name-swipe-asks")
        keepEditing(app)
        XCTAssertFalse(discardTitle.exists, "question dismissed")
        XCTAssertTrue(field.waitForExistence(timeout: 3), "Keep editing keeps the sheet")

        // Cancel: asks, Discard closes.
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(discardTitle.waitForExistence(timeout: 4), "Cancel asks")
        attach(app, "sheet-2-name-cancel-asks")
        app.buttons["Discard"].firstMatch.tap()
        XCTAssertTrue(waitUntilGone(field, timeout: 5), "Discard closes the sheet")

        // The sheet opens again (presentation state reset), and untouched it closes without asking.
        nameRow.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 8), "Edit name reopens")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertFalse(discardTitle.waitForExistence(timeout: 2), "no question without changes")
        XCTAssertTrue(waitUntilGone(field, timeout: 5))

        // Proof › Maintenance › Record an issue.
        app.buttons["Proof"].firstMatch.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Maintenance'")).firstMatch
        for _ in 0..<5 where !row.isHittable { app.swipeUp() }
        guard row.waitForExistence(timeout: 10) else { return XCTFail("Maintenance row") }
        row.tap()
        let add = app.buttons["Record an issue"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let title = app.textFields.firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap()
        title.typeText("Draft only")
        dismissSwipe(app)
        XCTAssertTrue(discardTitle.waitForExistence(timeout: 4), "issue swipe-down asks")
        attach(app, "sheet-3-issue-swipe-asks")
        app.buttons["Discard"].firstMatch.tap()
        XCTAssertTrue(waitUntilGone(title, timeout: 5), "issue sheet discarded")
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 8), "issue sheet reopens")
        app.buttons["Cancel"].firstMatch.tap()
    }

    /// Edit rental: amount pads get a keyboard Done; text fields chain with Next; Close asks once edited.
    func test03_EditRentalKeyboardAndClose() throws {
        let app = try signedIn()
        let viewAll = app.buttons["View all"].firstMatch
        for _ in 0..<4 where !viewAll.isHittable { app.swipeUp() }
        guard viewAll.waitForExistence(timeout: 5) else { return XCTFail("rental link") }
        viewAll.tap()
        let edit = app.buttons["Edit rental details"].firstMatch
        for _ in 0..<6 where !edit.isHittable { app.swipeUp() }
        guard edit.waitForExistence(timeout: 10) else { return XCTFail("Edit rental details") }
        edit.tap()
        let city = app.textFields["City"].firstMatch
        XCTAssertTrue(city.waitForExistence(timeout: 8), "City field")
        city.tap()
        dismissKeyboardTip(app)
        attach(app, "rental-1-city-keyboard")
        XCTAssertFalse(app.toolbars.buttons["Done"].exists, "no keyboard bar on a text field")
        app.typeText("\n")   // Next → Province
        attach(app, "rental-2-after-next")
        let deposit = app.textFields["Deposit amount"].firstMatch
        for _ in 0..<6 where !deposit.isHittable { app.swipeUp() }
        deposit.tap()
        attach(app, "rental-3-deposit-pad")
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3), "Done on the amount pad")
        deposit.typeText("12.3.4")
        done.tap()
        sleep(1)
        attach(app, "rental-4-amount-issue")
        XCTAssertTrue(app.staticTexts["Enter an amount, like 1500."].exists, "inline amount note")
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Discard changes?"].firstMatch.waitForExistence(timeout: 4), "Close asks")
        app.buttons["Discard"].firstMatch.tap()
        XCTAssertTrue(waitUntilGone(deposit, timeout: 5), "discarded")
    }

    // MARK: Helpers

    private func env(_ key: String) -> String? { ProcessInfo.processInfo.environment[key] }

    private func signedIn() throws -> XCUIApplication {
        guard let email = env("MM_VAULT_EMAIL"), let password = env("MM_VAULT_PASSWORD") else {
            throw XCTSkip("set TEST_RUNNER_MM_VAULT_EMAIL and TEST_RUNNER_MM_VAULT_PASSWORD")
        }
        let app = XCUIApplication()
        app.launch()
        if app.staticTexts["YOUR PROOF"].waitForExistence(timeout: 15) { return app }
        XCTAssertTrue(app.buttons["welcome.signIn"].waitForExistence(timeout: 10), "welcome")
        app.buttons["welcome.signIn"].tap()
        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 8))
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["auth.password"]
        passwordField.tap()
        passwordField.typeText(password + "\n")
        let notNow = app.buttons["Not Now"].firstMatch
        if notNow.waitForExistence(timeout: 6) { notNow.tap() }
        XCTAssertTrue(app.staticTexts["YOUR PROOF"].waitForExistence(timeout: 40), "Vault did not appear")
        return app
    }

    /// A short, slow drag up (no fling), so the page stops where the finger lifts.
    private func drag(_ app: XCUIApplication, by fraction: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        start.press(forDuration: 0.05,
                    thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7 - fraction)),
                    withVelocity: .slow, thenHoldForDuration: 0.3)
        sleep(1)
    }

    /// iOS 26 shows the question as a popover: its cancel-role action ("Keep editing") is a tap outside it
    /// (on a phone presented as an action sheet it is a button).
    private func keepEditing(_ app: XCUIApplication) {
        let keep = app.buttons["Keep editing"].firstMatch
        if keep.exists && keep.isHittable {
            keep.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        sleep(1)
    }

    /// The simulator's one-time keyboard tip ("Speed up your typing…") covers the keyboard.
    private func dismissKeyboardTip(_ app: XCUIApplication) {
        let tip = app.buttons["Continue"].firstMatch
        if tip.waitForExistence(timeout: 2) { tip.tap() }
    }

    /// The sheet's swipe-to-dismiss: a fast drag from just under its top edge to the bottom of the screen.
    private func dismissSwipe(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)),
                    withVelocity: .fast, thenHoldForDuration: 0)
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        if let dir = env("MM_QA_SHOT_DIR") {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
