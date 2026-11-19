//
//  RentalFormUITests.swift
//  movemorkUITests
//
//  Runtime check of the shared rental form (RentalFormFields) after the forms-polish × ugly-data merge.
//  Four scenarios, each its own test so none can hide inside another's skip:
//    - existing rental: Return walks the address fields in order, and an edit persists (restored afterwards)
//    - largest accessibility size: province stacks above postal, fields stay reachable and usable
//    - free account at the rental limit: Add a rental opens the paywall
//    - Pro account: Add a rental creates a rental
//  Same live setup as ReleaseValidationUITests, with disposable accounts that are never stored here:
//    TEST_RUNNER_MM_VAULT_EMAIL/PASSWORD   free account with exactly one rental
//    TEST_RUNNER_MM_PRO_EMAIL/PASSWORD     a FRESH disposable account per run (seeded with one export-ready
//                                          rental, `seed_vault_account.py --add-lease`) holding Pro. Delete rental
//                                          isn't live yet, so created rentals can't be cleaned up; reusing the
//                                          account would accumulate them, and test04 refuses to run on one that has.
//

import XCTest

final class RentalFormUITests: XCTestCase {
    private static let addressOrder = ["Street address", "Unit", "City", "Province / state", "Postal / ZIP code"]

    override func setUp() {
        continueAfterFailure = true
    }

    // MARK: Existing rental

    /// Default text size: Return moves focus Street → Unit → City → Province → Postal (exactly one field focused
    /// at each step), province and postal share a row, and a changed unit persists. The original unit is put
    /// back in a teardown block, so it is restored even when an assertion above fails.
    func test01_ExistingRentalFocusOrderAndPersistence() throws {
        let app = try signedIn(as: "VAULT")
        openEditRental(app)
        assertReturnWalksFields(app, Self.addressOrder)
        attach(app, "form-1-focus-reached-postal")

        let region = field(app, "Province / state"), postal = field(app, "Postal / ZIP code")
        XCTAssertEqual(region.frame.midY, postal.frame.midY, accuracy: 4, "province and postal share a row")
        XCTAssertLessThanOrEqual(region.frame.maxX, postal.frame.minX + 1, "province sits left of postal")

        let unit = reveal(app, field(app, "Unit"))
        let original = fieldText(unit)
        addTeardownBlock { [weak self] in self?.restoreUnit(original) }

        let marker = "QA \(Int(Date().timeIntervalSince1970) % 10000)"
        unit.tap()
        unit.replaceText(with: marker)
        save(app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
                        .waitForExistence(timeout: 15), "saved unit shows in Rental details")
        attach(app, "form-2-saved")

        app.terminate()
        let relaunched = try signedIn(as: "VAULT")
        openEditRental(relaunched)
        XCTAssertEqual(fieldText(reveal(relaunched, field(relaunched, "Unit"))), marker,
                       "the edit survives a relaunch (read back from the server)")
        cancelSheet(relaunched)
    }

    // MARK: Maximum Dynamic Type

    /// Largest accessibility size: every address field can be scrolled to and focused, Return still walks them
    /// in order, and province stacks above postal on the same leading edge. Fields are scrolled into view before
    /// any frame is read, so a field below the fold is not mistaken for a layout failure.
    func test02_MaximumDynamicTypeStacksAndStaysUsable() throws {
        let app = try signedIn(as: "VAULT",
                               arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openEditRental(app)
        assertReturnWalksFields(app, Self.addressOrder)
        app.typeText("\n")

        let region = field(app, "Province / state"), postal = field(app, "Postal / ZIP code")
        reveal(app, region)
        reveal(app, postal)
        XCTAssertTrue(region.isHittable && postal.isHittable, "both reachable at AX5")
        attach(app, "form-3-ax5-region-postal")
        XCTAssertGreaterThanOrEqual(postal.frame.minY, region.frame.maxY - 1, "postal stacks below province")
        XCTAssertEqual(region.frame.minX, postal.frame.minX, accuracy: 4, "stacked fields share a leading edge")

        let save = app.buttons["Save changes"].firstMatch
        reveal(app, save)
        XCTAssertTrue(save.isHittable, "Save changes reachable at AX5")
        cancelSheet(app)
    }

    // MARK: Add a rental

    /// Free plan with one rental: Add a rental opens the paywall, not the form.
    func test03_FreeAccountAtLimitGetsPaywall() throws {
        let app = try signedIn(as: "VAULT")
        tapAddRental(app)
        XCTAssertFalse(field(app, "Street address").waitForExistence(timeout: 4), "free account at its limit must not get the form")
        let paywall = app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Not now'")).firstMatch
        XCTAssertTrue(paywall.waitForExistence(timeout: 8), "paywall appears")
        attach(app, "form-4-free-paywall")
        if paywall.exists { paywall.tap() }
    }

    /// Pro: the app itself shows Pro as active (not just a dashboard grant), the account is fresh, then Add a
    /// rental opens the form, Return walks it, and Create rental record adds a uniquely named rental that
    /// appears in the rentals menu. Fails (never skips) without a Pro account, so rental creation can't be
    /// counted as verified by accident.
    func test04_ProAccountCreatesRental() throws {
        guard env("MM_PRO_EMAIL") != nil else {
            XCTFail("NOT VERIFIED: rental creation needs TEST_RUNNER_MM_PRO_EMAIL/PASSWORD (a fresh account with Pro)")
            return
        }
        let app = try signedIn(as: "PRO")
        guard assertClientShowsPro(app) else { return }
        app.buttons["Proof"].firstMatch.tap()
        let control = app.buttons.matching(NSPredicate(format: "label == 'Add a rental' OR label == 'Rentals'")).firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 10), "Add a rental / Rentals control")
        guard control.label == "Add a rental" else {
            XCTFail("PRO account already has more than one rental; seed a fresh disposable account for each run")
            return
        }
        tapAddRental(app)
        let street = field(app, "Street address")
        XCTAssertTrue(street.waitForExistence(timeout: 8), "Pro account gets the Add rental form")
        assertReturnWalksFields(app, Self.addressOrder)

        let tag = "QA\(UUID().uuidString.prefix(6))"
        let values = ["Street address": "\(tag) Test Street", "City": "Toronto", "Province / state": "ON",
                      "Postal / ZIP code": "M5J 2N8"]
        for (id, text) in values {
            let f = reveal(app, field(app, id))
            f.tap()
            f.replaceText(with: text)
        }
        app.typeText("\n")
        let create = app.buttons["Create rental record"].firstMatch
        reveal(app, create)
        XCTAssertTrue(create.isEnabled, "Create rental record enabled with an address")
        create.tap()
        XCTAssertTrue(app.staticTexts["Add your rental"].firstMatch.waitForNonExistence(timeout: 20), "form closed after create")
        attach(app, "form-5-created")

        tapRentalsMenu(app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", tag)).firstMatch
                        .waitForExistence(timeout: 15), "new rental \(tag) listed")
        attach(app, "form-6-rentals-menu")
    }

    /// Pro is recognised by the backend too, not only by the client: on the free plan the second report opens the
    /// paywall (test02_ReportGeneration in ReleaseValidationUITests), so with Pro a second report must start
    /// generating instead.
    func test05_BackendRecognisesPro() throws {
        guard env("MM_PRO_EMAIL") != nil else {
            XCTFail("NOT VERIFIED: needs TEST_RUNNER_MM_PRO_EMAIL/PASSWORD (a fresh account with Pro)")
            return
        }
        let app = try signedIn(as: "PRO")
        guard assertClientShowsPro(app) else { return }
        app.buttons["Reports"].firstMatch.tap()
        let generate = app.buttons["Generate report"].firstMatch
        let view = app.buttons["View report"].firstMatch
        if generate.waitForExistence(timeout: 20) { generate.tap() }
        XCTAssertTrue(view.waitForExistence(timeout: 150), "first report ready")
        let again = app.buttons["Generate new report"].firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 10), "Generate new report")
        again.tap()
        let paywall = app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Not now'")).firstMatch
        XCTAssertFalse(paywall.waitForExistence(timeout: 6), "Pro's second report must not open the paywall")
        attach(app, "form-7-pro-second-report")
        XCTAssertTrue(app.staticTexts["Generating report…"].waitForExistence(timeout: 10) || view.waitForExistence(timeout: 150),
                      "Pro's second report generates")
    }

    // MARK: Helpers

    private func env(_ key: String) -> String? { ProcessInfo.processInfo.environment[key] }

    private func field(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.textFields[id].firstMatch }

    private func fieldText(_ element: XCUIElement) -> String {
        guard let value = element.value as? String, value != element.placeholderValue else { return "" }
        return value
    }

    private func hasFocus(_ element: XCUIElement) -> Bool {
        element.exists && ((element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false)
    }

    /// The address fields that currently hold keyboard focus (should be exactly one while typing).
    private func focusedFields(_ app: XCUIApplication) -> [String] {
        Self.addressOrder.filter { hasFocus(field(app, $0)) }
    }

    private func waitForFocus(_ app: XCUIApplication, on id: String, timeout: TimeInterval = 4) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if focusedFields(app) == [id] { return true }
            usleep(200_000)
        }
        return false
    }

    /// Taps the first field, then presses Return through the rest, asserting after each step that focus is on
    /// the expected field and nowhere else.
    private func assertReturnWalksFields(_ app: XCUIApplication, _ order: [String]) {
        guard let first = order.first else { return }
        reveal(app, field(app, first)).tap()
        XCTAssertTrue(waitForFocus(app, on: first), "\(first) focused after tap (focused: \(focusedFields(app)))")
        for (from, to) in zip(order, order.dropFirst()) {
            app.typeText("\n")
            XCTAssertTrue(waitForFocus(app, on: to), "Return in \(from) focuses \(to) (focused: \(focusedFields(app)))")
        }
    }

    /// Scrolls until the element is hittable (up first if it is above the fold, then down).
    @discardableResult
    private func reveal(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        _ = element.waitForExistence(timeout: 8)
        let window = app.windows.firstMatch.frame
        for _ in 0..<8 where !element.isHittable {
            if element.exists && element.frame.maxY < window.minY + 80 { app.swipeDown() } else { app.swipeUp() }
        }
        return element
    }

    private func openEditRental(_ app: XCUIApplication) {
        let rental = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move-in proof'")).firstMatch
        XCTAssertTrue(rental.waitForExistence(timeout: 15), "rental record row")
        rental.tap()
        sleep(2)
        let edit = reveal(app, app.buttons["Edit rental details"].firstMatch)
        XCTAssertTrue(edit.isHittable, "Edit rental details reachable")
        edit.tap()
        XCTAssertTrue(app.staticTexts["Edit rental"].firstMatch.waitForExistence(timeout: 8), "Edit rental sheet")
    }

    private func save(_ app: XCUIApplication) {
        let save = reveal(app, app.buttons["Save changes"].firstMatch)
        XCTAssertTrue(save.isHittable, "Save changes reachable")
        save.tap()
        XCTAssertTrue(app.staticTexts["Edit rental"].firstMatch.waitForNonExistence(timeout: 15), "sheet closed after save")
    }

    private func cancelSheet(_ app: XCUIApplication) {
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap() }
        let discard = app.buttons["Discard"].firstMatch
        if discard.waitForExistence(timeout: 3) { discard.tap() }
    }

    /// Cleanup for test01: a fresh launch puts the original unit back, whatever state the test stopped in.
    private func restoreUnit(_ original: String) {
        guard let app = try? signedIn(as: "VAULT") else { return }
        openEditRental(app)
        let unit = reveal(app, field(app, "Unit"))
        guard unit.exists, fieldText(unit) != original else { cancelSheet(app); return }
        unit.tap()
        unit.replaceText(with: original)
        save(app)
    }

    /// Account shows "MoveMark Pro" / Subscription "Pro": the client sees the entitlement.
    @discardableResult
    private func assertClientShowsPro(_ app: XCUIApplication) -> Bool {
        app.buttons["Account"].firstMatch.tap()
        let pro = app.staticTexts["MoveMark Pro"].firstMatch
        // "MoveMark Pro" also titles other rows, so the free plan's own label must be gone too.
        let ok = pro.waitForExistence(timeout: 20) && !app.staticTexts["Free plan"].firstMatch.exists
        attach(app, "form-pro-account")
        XCTAssertTrue(ok, "the app shows MoveMark Pro for this account (the entitlement reached the client)")
        return ok
    }

    private func tapRentalsMenu(_ app: XCUIApplication) {
        let control = app.buttons.matching(NSPredicate(format: "label == 'Add a rental' OR label == 'Rentals'")).firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 10), "Add a rental / Rentals control")
        control.tap()
    }

    private func tapAddRental(_ app: XCUIApplication) {
        tapRentalsMenu(app)
        let add = app.buttons["Add a rental"].firstMatch
        if add.waitForExistence(timeout: 4) { add.tap() }
    }

    /// `account` is VAULT or PRO, read from TEST_RUNNER_MM_<account>_EMAIL/PASSWORD.
    private func signedIn(as account: String, arguments: [String] = []) throws -> XCUIApplication {
        guard let email = env("MM_\(account)_EMAIL"), let password = env("MM_\(account)_PASSWORD") else {
            throw XCTSkip("set TEST_RUNNER_MM_\(account)_EMAIL and TEST_RUNNER_MM_\(account)_PASSWORD")
        }
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()
        // Always sign in fresh, so a test never runs as whichever account a previous test left signed in.
        if !app.buttons["welcome.signIn"].waitForExistence(timeout: 15) {
            app.buttons["Account"].firstMatch.tap()
            let signOut = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sign out'")).firstMatch
            for _ in 0..<6 where !signOut.isHittable { app.swipeUp() }
            signOut.tap()
        }
        XCTAssertTrue(app.buttons["welcome.signIn"].waitForExistence(timeout: 20))
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

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

private extension XCUIElement {
    /// Clears the field (select-all is unreliable on custom fields, so delete key per character) and types.
    func replaceText(with text: String) {
        if let value = value as? String, !value.isEmpty, value != placeholderValue {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        typeText(text)
    }
}
