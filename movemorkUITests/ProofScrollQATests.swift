//
//  ProofScrollQATests.swift
//  movemorkUITests
//
//  @file Drives the Proof QA screen with real swipes (scroll, pull past top) and attaches each
//        frame, so scroll, parallax, sheet and tab-bar behaviour are checked physically
//  @domain design-system
//  @status wip
//  @see [[ProofHomeView.swift]]
//

import XCTest

final class ProofScrollQATests: XCTestCase {
    @MainActor
    func testProofScrollFrames() {
        let app = XCUIApplication()
        app.launchArguments = ["-MMRichQA", "proof-home"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Your proof"].waitForExistence(timeout: 10))

        func capture(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
            if let dir = ProcessInfo.processInfo.environment["MM_QA_SHOT_DIR"] {
                try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
            }
        }

        capture("1-rest")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        capture("2-scrolled")
        app.swipeUp()
        capture("3-bottom")
        app.swipeDown(); app.swipeDown()
        // Hold a pull past the top to see the hero stretch.
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        top.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)), withVelocity: .slow, thenHoldForDuration: 0.6)
        capture("4-pulled")
    }
}
