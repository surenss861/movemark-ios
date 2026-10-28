//
//  TempLandscapeProbe.swift
//  movemorkUITests
//
//  TEMPORARY diagnostic — delete after the landscape boundary check.
//

import XCTest

final class TempLandscapeProbe: XCTestCase {

    @MainActor
    func testWelcomeLandscapeReachability() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launch()

        XCUIDevice.shared.orientation = .landscapeLeft
        _ = app.buttons["welcome.primaryCTA"].waitForExistence(timeout: 5)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "welcome-landscape"
        shot.lifetime = .keepAlways
        add(shot)

        let cta = app.buttons["welcome.primaryCTA"]
        let signIn = app.buttons["welcome.signIn"]
        print("PROBE cta.exists=\(cta.exists) cta.hittable=\(cta.exists ? cta.isHittable : false) frame=\(cta.exists ? "\(cta.frame)" : "n/a")")
        print("PROBE signIn.exists=\(signIn.exists) signIn.hittable=\(signIn.exists ? signIn.isHittable : false)")
        print("PROBE window=\(app.windows.firstMatch.frame)")

        XCUIDevice.shared.orientation = .portrait
    }
}
