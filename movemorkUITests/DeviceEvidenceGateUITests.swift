//
//  DeviceEvidenceGateUITests.swift
//  movemorkUITests
//
//  Physical-device evidence gate driver (Neon dev only, opt-in): signs up the QA account, creates a
//  rental and room, adds one Photos-library photo and one in-app camera photo, and generates the
//  move-in report — through the real UI. Verification happens host-side (scripts/qa/device_evidence_verify.py).
//

import XCTest

final class DeviceEvidenceGateUITests: XCTestCase {
    private var app: XCUIApplication!
    private let dumpDir = ProcessInfo.processInfo.environment["MM_UI_DUMP_DIR"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for label in ["Allow", "OK", "Allow Full Access", "Allow Access to All Photos", "Continue"] where alert.buttons[label].exists {
                alert.buttons[label].tap(); return true
            }
            return false
        }
    }

    private func dump(_ name: String) {
        guard let dumpDir else { return }
        try? app.debugDescription.write(toFile: "\(dumpDir)/\(name).txt", atomically: true, encoding: .utf8)
    }

    /// Scrolls a field out from under the keyboard before typing.
    private func typeInto(_ field: XCUIElement, _ text: String) {
        // Coordinate tap: SwiftUI can report a visible field as not hittable under a transparent overlay.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        field.typeText(text)
    }

    private var qaPassword: String { ProcessInfo.processInfo.environment["MM_QA_PASSWORD"] ?? "" }

    /// Signs in unless a stored session already did (the Keychain survives relaunches).
    private func signIn() {
        let signIn = app.buttons["welcome.signIn"]
        guard signIn.waitForExistence(timeout: 12) else { return }
        signIn.tap()
        let email = app.textFields["auth.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap(); email.typeText("qa-neon-a@movemark.test")
        let password = app.secureTextFields["auth.password"]
        password.tap(); password.typeText(qaPassword)
        app.buttons["auth.primaryAction"].tap()
    }

    func testDeviceEvidenceGate() throws {
        XCTAssertFalse(qaPassword.isEmpty, "MM_QA_PASSWORD not set")
        app.launch()
        signIn()
        dismissSavePassword()
        let fields = app.textFields
        // A tap during the Save Password sheet's dismissal animation is swallowed: retry until the form opens.
        for _ in 0..<3 where !fields.element(boundBy: 0).exists {
            tapButton(containing: "I just moved in")
            _ = fields.element(boundBy: 0).waitForExistence(timeout: 6)
        }
        XCTAssertTrue(fields.element(boundBy: 0).exists, "rental form never opened")
        typeInto(fields.element(boundBy: 0), "QA A")
        replaceText(fields.element(boundBy: 1), "QA ONLY device gate")
        typeInto(fields.element(boundBy: 2), "Toronto")
        tapButton(containing: "Start move-in proof")
        tapButton(containing: "Start room proof")
        tapButton(containing: "Choose from gallery")
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 15))
        dump("14-picker")
        let close = app.buttons["Close"].firstMatch  // the picker's first-run banner
        if close.exists && close.isHittable { close.tap() }
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        #if !targetEnvironment(simulator)
        captureCameraPhoto()
        #endif
        tapButton(containing: "Save proof")
        XCTAssertTrue(app.staticTexts["Saved to your vault"].waitForExistence(timeout: 60))
        #if !targetEnvironment(simulator)
        // A partial save still says "Saved to your vault": check the count the app itself reports.
        let savedBoth = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '2 photos saved'")).firstMatch
        XCTAssertTrue(savedBoth.exists, "not every photo was saved")
        #endif
        tapButton(containing: "View proof vault")
        sleep(4); dump("18-vault")
        tapButton(containing: "Listing proof")
        let uploads = app.buttons.matching(NSPredicate(format: "label == 'Upload'"))
        XCTAssertTrue(uploads.element(boundBy: 2).waitForExistence(timeout: 10))
        uploads.element(boundBy: 2).tap()
        sleep(2); dump("19-upload-sheet")
        tapButton(containing: "Choose photo")
        let listingPhoto = app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 1)
        XCTAssertTrue(listingPhoto.waitForExistence(timeout: 15))
        listingPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(2); dump("20-after-pick")
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        XCTAssertTrue(app.staticTexts["Report ready to make"].waitForExistence(timeout: 60))
        app.buttons["BackButton"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Reports"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Reports"].firstMatch.tap()
        tapButton(containing: "Make report", timeout: 30)
        sleep(3); dump("22-making")
        let share = app.buttons.matching(NSPredicate(format: "label CONTAINS 'View / Share'")).firstMatch
        let ready = share.waitForExistence(timeout: 240)
        dump("23-report")
        XCTAssertTrue(ready, "move-in report never became ready")
    }

    /// Step two, run after host-side verification: delete the QA account through the app's own flow.
    func testDeleteAccountThroughApp() throws {
        app.launch()
        signIn()
        let accountTab = app.buttons["Account"].firstMatch
        XCTAssertTrue(accountTab.waitForExistence(timeout: 20))
        accountTab.tap()
        let deletion = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Account & Data Deletion'")).firstMatch
        for _ in 0..<6 where !(deletion.exists && deletion.isHittable) { app.swipeUp() }
        deletion.tap()
        tapButton(containing: "Delete Account Permanently")
        let confirm = app.buttons["Delete Permanently"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        confirm.tap()
        XCTAssertTrue(app.buttons["welcome.signIn"].waitForExistence(timeout: 90), "app did not return to the signed-out welcome screen")
    }

    /// In-app AVFoundation camera (devices only: the simulator has no camera).
    private func captureCameraPhoto() {
        tapButton(containing: "Take photos")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        let shutter = app.buttons["camera.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 15))
        sleep(2)  // let exposure and focus settle
        shutter.tap()
        let use = app.buttons["camera.use"]
        XCTAssertTrue(use.waitForExistence(timeout: 20))
        dump("15-camera-review")
        use.tap()
        XCTAssertTrue(app.staticTexts["2 photos ready to save"].waitForExistence(timeout: 15))
    }

    private func replaceText(_ field: XCUIElement, _ text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let existing = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + text)
    }

    /// The Save Password prompt belongs to the app on the simulator but to SpringBoard on devices.
    private func dismissSavePassword() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<8 {
            for host in [app!, springboard] where host.buttons["Not Now"].exists {
                host.buttons["Not Now"].tap(); return
            }
            sleep(1)
        }
        // On devices iOS 26 shows it from the Passwords service, which XCUITest can't query: if the first
        // screen is still covered, tap where its "Not Now" button sits (left button, ~62% down the screen).
        let firstChoice = app.buttons.matching(NSPredicate(format: "label CONTAINS 'I just moved in'")).firstMatch
        if firstChoice.waitForExistence(timeout: 10) && !firstChoice.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.33, dy: 0.617)).tap()
            sleep(2)
            XCTAssertTrue(firstChoice.isHittable, "Save Password sheet still covering the app")
        }
    }

    private func tapButton(containing text: String, timeout: TimeInterval = 15) {
        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "no button containing \(text)")
        let hittable = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: button)
        if XCTWaiter().wait(for: [hittable], timeout: 8) == .completed {
            button.tap()
        } else {
            // Covered by something (system sheet, transparent overlay): record the screen, then tap its centre.
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "covered-\(text)"; shot.lifetime = .keepAlways; add(shot)
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
