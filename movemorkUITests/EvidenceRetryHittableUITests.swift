//
//  EvidenceRetryHittableUITests.swift
//  movemorkUITests
//
//  @file A partial save's retry must be reachable: on the production room screen (`-MMRichQA evidence-retry`,
//        123 Main St → Storage, "2 of 8 photos saved. 6 photos need retry."), both Retry controls are fully on
//        screen and hittable when the failure state shows, at the default text size and at a large
//        accessibility size, with and without the keyboard up (Label field focused), and a tap on them reaches
//        the screen's retry.
//  @domain evidence
//  @status stable
//  @see [[MMEvidenceRetryQAFixture.swift]]
//

import XCTest

final class EvidenceRetryHittableUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testRetryHittableDefaultSize() {
        runRetryCheck(contentSize: nil, name: "default")
    }

    @MainActor
    func testRetryHittableAccessibilityLarge() {
        runRetryCheck(contentSize: "UICTContentSizeCategoryAccessibilityL", name: "axL")
    }

    @MainActor
    func testRetryHittableWithKeyboardDefaultSize() {
        runRetryCheck(contentSize: nil, name: "kb-default", keyboard: true)
    }

    @MainActor
    func testRetryHittableWithKeyboardAccessibilityLarge() {
        runRetryCheck(contentSize: "UICTContentSizeCategoryAccessibilityL", name: "kb-axL", keyboard: true)
    }

    @MainActor
    private func runRetryCheck(contentSize: String?, name: String, keyboard: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-MMRichQA", "evidence-retry"]
        if let contentSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize] }
        app.launch()

        let notice = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "6 photos need retry")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 15), "partial-save notice not shown")
        // Let the screen's own scroll-to-warning settle.
        sleep(2)
        attach(app, "\(name)-failure-state")

        let window = app.windows.firstMatch.frame
        var bottomLimit = window.maxY

        if keyboard {
            // Focus the form's Label field (scrolling to it first), so the keyboard is up during the checks.
            let field = app.textFields["Label"].firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5), "Label field not found")
            var swipes = 0
            while !field.isHittable && swipes < 6 { app.swipeUp(); swipes += 1 }
            field.tap()
            let kb = app.keyboards.firstMatch
            XCTAssertTrue(kb.waitForExistence(timeout: 5), "keyboard did not appear")
            sleep(1)
            bottomLimit = kb.frame.minY
            attach(app, "\(name)-keyboard")
        }

        // The notice's Try again (the retry for the remaining photos).
        let tryAgain = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Try again")).firstMatch
        XCTAssertTrue(tryAgain.exists, "Try again not found:\n\(app.debugDescription)")
        XCTAssertTrue(tryAgain.isHittable, "Try again not hittable, frame \(tryAgain.frame) in \(window)")
        XCTAssertTrue(window.contains(tryAgain.frame), "Try again clipped: \(tryAgain.frame) in \(window)")
        XCTAssertLessThanOrEqual(tryAgain.frame.maxY, bottomLimit + 0.5,
                                 "Try again \(tryAgain.frame) is under the keyboard / bottom edge (\(bottomLimit))")

        // The status line's Retry ("Retry upload"). With the keyboard up it may have scrolled away with the form:
        // it must be reachable by scrolling back (drags in the upper half, clear of the keyboard).
        let retryUpload = app.buttons["Retry upload"]
        if keyboard {
            // Short, slow drags (no fling) toward the status line until it sits between the bar and the notice;
            // the visible band is small on an SE with the keyboard up at a large text size.
            let barBottom = app.buttons["Back"].firstMatch.frame.maxY
            var drags = 0
            while drags < 30, retryUpload.exists {
                let frame = retryUpload.frame
                let top = min(tryAgain.frame.minY, notice.frame.minY)
                if frame.minY >= barBottom && frame.maxY <= top { break }
                let down = frame.minY < barBottom   // above the band: pull the content down
                let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.2 : 0.26))
                let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.26 : 0.2))
                from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
                drags += 1
            }
            attach(app, "\(name)-keyboard-scrolled")
        }
        XCTAssertTrue(retryUpload.exists, "Retry upload not found:\n\(app.debugDescription)")
        XCTAssertTrue(retryUpload.isHittable, "Retry upload not hittable, frame \(retryUpload.frame) in \(window)")
        XCTAssertTrue(window.contains(retryUpload.frame), "Retry upload clipped: \(retryUpload.frame) in \(window)")
        // isHittable alone misses SwiftUI overlap: the status line's Retry must sit fully above the pinned notice.
        let noticeTop = min(tryAgain.frame.minY, notice.frame.minY)
        XCTAssertLessThanOrEqual(retryUpload.frame.maxY, noticeTop,
                                 "Retry upload \(retryUpload.frame) is under the pinned notice (top \(noticeTop))")
        // And below the navigation bar (the screen scrolls under it).
        let back = app.buttons["Back"].firstMatch
        if back.exists {
            XCTAssertGreaterThanOrEqual(retryUpload.frame.minY, back.frame.maxY,
                                        "Retry upload \(retryUpload.frame) is under the navigation bar")
        }

        // A tap reaches the screen's retry: the fixture has no account, so the save answers with sign-in.
        // (The keyboard runs tap the status line's Retry; the others the notice's Try again.)
        if keyboard { retryUpload.tap() } else { tryAgain.tap() }
        let signIn = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "sign in")).firstMatch
        XCTAssertTrue(signIn.waitForExistence(timeout: 5), "Retry tap did not reach the retry")
        attach(app, "\(name)-after-tap")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        if let dir = ProcessInfo.processInfo.environment["MM_QA_SHOT_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("retry-\(name).png"))
        }
    }
}
