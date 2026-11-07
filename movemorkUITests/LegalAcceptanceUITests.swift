//
//  LegalAcceptanceUITests.swift
//  movemorkUITests
//
//  @file The agreement screen's rule, on the DEBUG fixture (`-MMRichQA legal`): nothing happens until the box is ticked.
//        The record itself is covered by the server tests.
//  @domain onboarding-auth
//  @status wip
//

import XCTest

final class LegalAcceptanceUITests: XCTestCase {
    func testContinueNeedsTheBoxTicked() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-MMRichQA", "legal"]
        app.launch()

        let agree = app.buttons["legal.agree"]
        let proceed = app.buttons["legal.continue"]
        let count = app.staticTexts["legal.acceptedCount"]
        XCTAssertTrue(agree.waitForExistence(timeout: 15))
        XCTAssertFalse(proceed.isEnabled, "starts unticked and disabled")
        XCTAssertEqual(agree.value as? String, "Not checked")
        XCTAssertTrue(app.links["Terms of Service"].exists || app.buttons["Terms of Service"].exists)
        XCTAssertTrue(app.links["Privacy Policy"].exists || app.buttons["Privacy Policy"].exists)

        agree.tap()
        XCTAssertTrue(proceed.isEnabled)
        agree.tap()
        XCTAssertFalse(proceed.isEnabled, "unticking turns it off again")
        XCTAssertEqual(count.label, "accepted 0")

        agree.tap()
        proceed.tap()
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        let accepted = NSPredicate(format: "label == 'accepted 1'")
        wait(for: [expectation(for: accepted, evaluatedWith: count)], timeout: 5)
    }
}
