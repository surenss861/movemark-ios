//
//  WelcomeAccessibilityUITests.swift
//  movemorkUITests
//
//  Gate: Accessibility Dynamic Type scroll fallback — Start free + Sign in reachable.
//

import XCTest

final class WelcomeAccessibilityUITests: XCTestCase {

    @MainActor
    func testWelcomeActionsReachableAtAccessibilityXXXL() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let cta = app.buttons["welcome.primaryCTA"]
        let signIn = app.buttons["welcome.signIn"]

        XCTAssertTrue(cta.waitForExistence(timeout: 8), "Start free CTA should exist at AX XXXL")
        XCTAssertTrue(signIn.waitForExistence(timeout: 8), "Sign in should exist at AX XXXL")

        // Content may extend past the first viewport; scroll until both actions are hittable.
        for _ in 0..<6 {
            if cta.isHittable, signIn.isHittable { break }
            app.swipeUp()
        }

        XCTAssertTrue(cta.isHittable, "Start free must be reachable after AX scroll")
        XCTAssertTrue(signIn.isHittable, "Sign in must be reachable after AX scroll")
    }

    @MainActor
    func testWelcomeActionsReachableAtAccessibilityLarge() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityLarge",
        ]
        app.launch()

        let cta = app.buttons["welcome.primaryCTA"]
        let signIn = app.buttons["welcome.signIn"]

        XCTAssertTrue(cta.waitForExistence(timeout: 8))
        XCTAssertTrue(signIn.waitForExistence(timeout: 8))

        for _ in 0..<6 {
            if cta.isHittable, signIn.isHittable { break }
            app.swipeUp()
        }

        XCTAssertTrue(cta.isHittable)
        XCTAssertTrue(signIn.isHittable)
    }
}
