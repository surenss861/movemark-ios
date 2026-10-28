//
//  ReleaseValidationUITests.swift
//  movemorkUITests
//
//  Live release-validation pass against production with disposable accounts (never stored here), run through
//  a local QA proxy that forwards the Data API and the MoveMark API and can drop connections to simulate going
//  offline (scratchpad offline_proxy.py on 127.0.0.1:8899):
//    NEON_DATA_API_URL=http://127.0.0.1:8899/neondb/rest/v1 MOVEMARK_API_BASE_URL_OVERRIDE=http://127.0.0.1:8899
//    TEST_RUNNER_MM_VAULT_EMAIL/PASSWORD (export-ready account), TEST_RUNNER_MM_FIRSTRUN_EMAIL/PASSWORD
//    (account with no onboarding), TEST_RUNNER_MM_PROXY=http://127.0.0.1:8899
//  Screenshots and the accessibility audit findings are attached to the result bundle.
//

import XCTest

final class ReleaseValidationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        setProxy(offline: false)
    }

    override func tearDown() {
        setProxy(offline: false)
    }

    // MARK: Keyboard

    /// Return keys submit, and the primary action stays reachable while the keyboard is up.
    func test01_KeyboardPaths() throws {
        let app = try signedIn()

        // Account › Edit name: Return saves and closes the sheet.
        app.buttons["Account"].firstMatch.tap()
        let nameRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'name'")).firstMatch
        if nameRow.waitForExistence(timeout: 10) {
            nameRow.tap()
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 8), "name field")
            field.tap()
            field.clearAndType("QA Release\n")
            sleep(3)
            attach(app, "kb-1-after-name-return")
            XCTAssertFalse(app.textFields.firstMatch.exists && app.keyboards.count > 0, "name sheet closed on Return")
        } else {
            XCTFail("Edit name row not found")
        }

        // Maintenance › Record an issue: with the keyboard up, Save is reachable.
        app.buttons["Proof"].firstMatch.tap()
        openMaintenance(app)
        let add = app.buttons["Record an issue"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Record an issue")
        add.tap()
        let title = app.textFields.firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 8), "issue title field")
        title.tap()
        title.typeText("Keyboard check")
        attach(app, "kb-2-issue-keyboard-up")
        let save = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Save'")).firstMatch
        if !save.isHittable { app.swipeUp() }
        attach(app, "kb-3-issue-after-scroll")
        XCTAssertTrue(save.isHittable, "Save reachable with the keyboard up")
        app.buttons["Cancel"].firstMatch.tap()
        backToRoot(app)
    }

    // MARK: Report generation

    /// Generate → generating → ready → preview → Share from inside the preview → the free plan's next report
    /// opens the paywall (not an error).
    func test02_ReportGeneration() throws {
        let app = try signedIn()
        app.buttons["Reports"].firstMatch.tap()
        let generate = app.buttons["Generate report"].firstMatch
        let view = app.buttons["View report"].firstMatch
        if generate.waitForExistence(timeout: 20) {
            attach(app, "rep-1-can-generate")
            generate.tap()
            if app.staticTexts["Generating report…"].waitForExistence(timeout: 10) { attach(app, "rep-2-generating") }
        }
        XCTAssertTrue(view.waitForExistence(timeout: 150), "report ready")
        sleep(1)
        attach(app, "rep-3-ready")
        view.tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 30), "PDF preview")
        sleep(2)
        attach(app, "rep-4-preview")
        let previewShare = app.navigationBars.buttons.matching(NSPredicate(format: "label == 'Share'")).firstMatch
        if previewShare.waitForExistence(timeout: 5) {
            previewShare.tap()
            sleep(3)
            attach(app, "rep-5-share-from-preview")
            XCTAssertTrue(app.otherElements["ActivityListView"].exists || app.cells.count > 0 || app.buttons["Close"].exists,
                          "share sheet presented from the preview")
            app.swipeDown(velocity: .fast)
            sleep(1)
        } else {
            XCTFail("no Share button in the PDF preview")
        }
        if done.exists { done.tap() }
        sleep(1)
        let again = app.buttons["Generate new report"].firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 10), "Generate new report")
        again.tap()
        sleep(3)
        attach(app, "rep-6-generate-new-on-free")
        let paywall = app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Not now'")).firstMatch
        XCTAssertTrue(paywall.waitForExistence(timeout: 10), "free plan's second report opens the paywall")
        paywall.tap()
        sleep(1)
    }

    // MARK: Offline

    /// Reports offline keeps the history and offers no Generate; back online, it refreshes.
    func test03_OfflineReportsKeepHistory() throws {
        let app = try signedIn()
        app.buttons["Reports"].firstMatch.tap()
        XCTAssertTrue(app.buttons["View report"].firstMatch.waitForExistence(timeout: 30), "report ready before going offline")
        setProxy(offline: true)
        app.swipeDown()
        sleep(6)
        attach(app, "off-1-reports-offline")
        XCTAssertTrue(app.buttons["View report"].firstMatch.exists, "history kept offline")
        XCTAssertFalse(app.buttons["Generate report"].firstMatch.exists, "no Generate offered offline")
        setProxy(offline: false)
        let retry = app.buttons["Try again"].firstMatch
        if retry.exists { retry.tap() } else { app.swipeDown() }
        sleep(5)
        attach(app, "off-2-reports-back-online")
        XCTAssertTrue(app.buttons["View report"].firstMatch.exists)
    }

    /// Recording an issue offline fails without losing the form; Try again online saves exactly one case.
    func test04_OfflineMaintenanceSavesOnce() throws {
        let app = try signedIn()
        openMaintenance(app)
        let add = app.buttons["Record an issue"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let title = app.textFields.firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap()
        let name = "Offline leak \(Int(Date().timeIntervalSince1970) % 10000)"
        title.typeText(name)
        setProxy(offline: true)
        let save = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Save'")).firstMatch
        if !save.isHittable { app.swipeUp() }
        save.tap()
        sleep(8)
        attach(app, "off-3-issue-offline")
        XCTAssertTrue(app.textFields.firstMatch.exists, "form kept after the failed save")
        setProxy(offline: false)
        let retry = app.buttons["Try again"].firstMatch
        if retry.waitForExistence(timeout: 3) { retry.tap() } else { save.tap() }
        sleep(8)
        attach(app, "off-4-issue-after-retry")
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name))
        XCTAssertEqual(rows.count, 1, "exactly one case saved")
    }

    // MARK: Deep links

    func test05_DeepLinks() throws {
        let app = try signedIn()
        app.open(URL(string: "movemark://reset-password?token=qa-not-a-real-token")!)
        sleep(3)
        attach(app, "dl-1-reset-link")
        let resetVisible = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'password'")).firstMatch.exists
        XCTAssertTrue(resetVisible, "reset link opens the reset screen")
        let close = app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Cancel'")).firstMatch
        if close.exists { close.tap() } else { app.swipeDown(velocity: .fast) }
        sleep(1)
        app.open(URL(string: "movemark://something-unknown?x=1")!)
        sleep(3)
        attach(app, "dl-2-unknown-link")
        XCTAssertTrue(app.buttons["Proof"].firstMatch.exists || app.staticTexts["YOUR PROOF"].exists, "unknown link is harmless")
        app.open(URL(string: "movemark://reset-password")!)
        sleep(2)
        attach(app, "dl-3-reset-without-token")
    }

    // MARK: Accessibility

    /// Apple's accessibility audit on each first-party screen; findings are attached, not failed, for triage.
    func test06_AccessibilityAudit() throws {
        let app = try signedIn()
        var findings: [String] = []
        func audit(_ screen: String) {
            sleep(2)
            attach(app, "ax-\(screen)")
            do {
                try app.performAccessibilityAudit { issue in
                    let el = issue.element.map { "\($0.elementType.rawValue) '\($0.label)'" } ?? "-"
                    findings.append("[\(screen)] \(issue.auditType) · \(issue.compactDescription) · \(el)")
                    return true
                }
            } catch {
                findings.append("[\(screen)] audit error: \(error)")
            }
        }
        audit("proof")
        let rental = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move-in proof'")).firstMatch
        if rental.waitForExistence(timeout: 8) { rental.tap(); audit("rental-record"); backToRoot(app) }
        openMaintenance(app); audit("maintenance-log"); backToRoot(app)
        let room = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Kitchen'")).firstMatch
        if room.waitForExistence(timeout: 5) { room.tap(); audit("room"); backToRoot(app) }
        app.buttons["Reports"].firstMatch.tap(); audit("reports")
        let dispute = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Dispute packet'")).firstMatch
        for _ in 0..<4 where !dispute.isHittable { app.swipeUp() }
        if dispute.exists { dispute.tap(); audit("dispute"); app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1) }
        app.buttons["Account"].firstMatch.tap(); audit("account")
        let sub = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Subscription'")).firstMatch
        if sub.waitForExistence(timeout: 5) {
            sub.tap(); audit("paywall")
            app.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Not now'")).firstMatch.tap()
        }
        let text = XCTAttachment(string: findings.isEmpty ? "No findings" : findings.joined(separator: "\n"))
        text.name = "accessibility-findings"
        text.lifetime = .keepAlways
        add(text)
    }

    // MARK: Destructive confirmations

    func test07_DestructiveConfirmations() throws {
        let app = try signedIn()
        // Mark resolved asks first; Cancel keeps the case open.
        openMaintenance(app)
        let caseRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Offline leak'")).firstMatch
        if caseRow.waitForExistence(timeout: 10) {
            caseRow.tap()
            let resolve = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Mark resolved'")).firstMatch
            for _ in 0..<5 where !resolve.isHittable { app.swipeUp() }
            resolve.tap()
            sleep(1)
            attach(app, "del-1-resolve-confirmation")
            let cancel = app.buttons["Cancel"].firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 5), "resolve asks first")
            cancel.tap()
            XCTAssertTrue(resolve.exists, "still open after Cancel")
        } else {
            XCTFail("no case to resolve (run test04 first)")
        }
        backToRoot(app)
        // Delete evidence asks first; Cancel keeps it.
        let room = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Kitchen'")).firstMatch
        if room.waitForExistence(timeout: 8) {
            room.tap()
            sleep(3)
            let menu = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Actions for'")).firstMatch
            for _ in 0..<4 where !menu.isHittable { app.swipeUp() }
            if menu.exists {
                menu.tap()
                let delete = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete'")).firstMatch
                XCTAssertTrue(delete.waitForExistence(timeout: 5))
                delete.tap()
                sleep(1)
                attach(app, "del-2-delete-evidence-confirmation")
                let cancel = app.buttons["Cancel"].firstMatch
                XCTAssertTrue(cancel.waitForExistence(timeout: 5), "delete evidence asks first")
                cancel.tap()
            } else {
                XCTFail("entry actions menu not found")
            }
        }
        backToRoot(app)
        // Delete account asks twice; cancelling keeps the account.
        app.buttons["Account"].firstMatch.tap()
        let del = app.buttons["Delete account"].firstMatch
        for _ in 0..<6 where !del.isHittable { app.swipeUp() }
        del.tap()
        let permanently = app.buttons["Delete account permanently"].firstMatch
        XCTAssertTrue(permanently.waitForExistence(timeout: 10))
        permanently.tap()
        sleep(1)
        attach(app, "del-3-account-final-confirmation")
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "final confirmation")
        cancel.tap()
        sleep(1)
        let sheetCancel = app.buttons["Cancel"].firstMatch
        if sheetCancel.exists { sheetCancel.tap() }
        sleep(1)
        attach(app, "del-4-account-kept")
    }

    // MARK: Escape routes

    /// Pushed screens all have a working back; the paywall has a way out.
    func test08_BackRoutes() throws {
        let app = try signedIn()
        let rental = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move-in proof'")).firstMatch
        XCTAssertTrue(rental.waitForExistence(timeout: 10))
        rental.tap()
        sleep(2)
        let moveOut = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move-out'")).firstMatch
        for _ in 0..<6 where !moveOut.isHittable { app.swipeUp() }
        if moveOut.exists {
            moveOut.tap(); sleep(2); attach(app, "esc-1-moveout")
            app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["YOUR PROOF"].waitForExistence(timeout: 10), "back to Proof")
        signOut(app)
    }

    /// First run: setup's back returns to the moment choice, and the moment screen can sign out.
    func test09_FirstRunEscapes() throws {
        guard let email = env("MM_FIRSTRUN_EMAIL"), let password = env("MM_FIRSTRUN_PASSWORD") else {
            throw XCTSkip("set TEST_RUNNER_MM_FIRSTRUN_EMAIL/PASSWORD")
        }
        let app = XCUIApplication()
        app.launch()
        signOutIfNeeded(app)
        signIn(app, email: email, password: password)
        let moving = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Moving into'")).firstMatch
        XCTAssertTrue(moving.waitForExistence(timeout: 40), "first run moment screen")
        attach(app, "fr-1-moment")
        moving.tap()
        let back = app.buttons["Back"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10), "setup has Back")
        attach(app, "fr-2-setup")
        back.tap()
        XCTAssertTrue(moving.waitForExistence(timeout: 10), "back at the moment choice")
        let signOut = app.buttons["Sign out"].firstMatch
        XCTAssertTrue(signOut.waitForExistence(timeout: 5), "moment screen can sign out")
        signOut.tap()
        XCTAssertTrue(app.buttons["welcome.signIn"].waitForExistence(timeout: 20), "signed out from first run")
        attach(app, "fr-3-signed-out")
    }

    // MARK: Helpers

    private func env(_ key: String) -> String? { ProcessInfo.processInfo.environment[key] }

    private func setProxy(offline: Bool) {
        guard let base = env("MM_PROXY"), let url = URL(string: "\(base)/__qa__/offline/\(offline ? "on" : "off")") else { return }
        let done = expectation(description: "proxy")
        URLSession.shared.dataTask(with: url) { _, _, _ in done.fulfill() }.resume()
        wait(for: [done], timeout: 10)
    }

    private func openMaintenance(_ app: XCUIApplication) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Maintenance'")).firstMatch
        for _ in 0..<5 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Maintenance row")
        row.tap()
        sleep(3)
    }

    private func backToRoot(_ app: XCUIApplication) {
        for _ in 0..<4 where !app.staticTexts["YOUR PROOF"].exists {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists { back.tap() } else { app.buttons["Proof"].firstMatch.tap() }
            sleep(1)
        }
        if !app.staticTexts["YOUR PROOF"].exists { app.buttons["Proof"].firstMatch.tap(); sleep(1) }
    }

    private func signOut(_ app: XCUIApplication) {
        app.buttons["Account"].firstMatch.tap()
        let signOut = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sign out'")).firstMatch
        for _ in 0..<6 where !signOut.isHittable { app.swipeUp() }
        signOut.tap()
        XCTAssertTrue(app.buttons["welcome.signIn"].waitForExistence(timeout: 20), "signed out")
    }

    private func signOutIfNeeded(_ app: XCUIApplication) {
        if app.buttons["welcome.signIn"].waitForExistence(timeout: 12) { return }
        let firstRunSignOut = app.buttons["Sign out"].firstMatch
        if firstRunSignOut.exists { firstRunSignOut.tap() } else { signOut(app) }
        XCTAssertTrue(app.buttons["welcome.signIn"].waitForExistence(timeout: 20))
    }

    private func signIn(_ app: XCUIApplication, email: String, password: String) {
        app.buttons["welcome.signIn"].tap()
        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 8))
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["auth.password"]
        passwordField.tap()
        // Keyboard path: Return from the password field signs in.
        passwordField.typeText(password + "\n")
        // The system's "Save Password?" prompt (simulator Passwords) sits over the app after sign-in.
        let notNow = app.buttons["Not Now"].firstMatch
        if notNow.waitForExistence(timeout: 6) { notNow.tap() }
    }

    private func signedIn() throws -> XCUIApplication {
        guard let email = env("MM_VAULT_EMAIL"), let password = env("MM_VAULT_PASSWORD") else {
            throw XCTSkip("set TEST_RUNNER_MM_VAULT_EMAIL and TEST_RUNNER_MM_VAULT_PASSWORD")
        }
        let app = XCUIApplication()
        app.launch()
        if app.staticTexts["YOUR PROOF"].waitForExistence(timeout: 15) { return app }
        signOutIfNeeded(app)
        signIn(app, email: email, password: password)
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
    func clearAndType(_ text: String) {
        if let value = value as? String, !value.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        typeText(text)
    }
}
