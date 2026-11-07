//
//  CameraShutterDeviceUITests.swift
//  movemorkUITests
//
//  Device QA for the shutter, on a phone already signed in with a Capture button on Proof and camera permission
//  granted. Takes real shots and never taps Save: the photos stay pending on the phone, nothing uploads.
//

import XCTest

final class CameraShutterDeviceUITests: XCTestCase {
    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testRepeatedShotsKeepTheAppAlive() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let capture = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Capture '")).firstMatch
        XCTAssertTrue(capture.waitForExistence(timeout: 25), "no Capture button: is the phone signed in on Proof?")
        capture.tap()
        let take = app.buttons["Take photos"]
        XCTAssertTrue(take.waitForExistence(timeout: 15), "no Take photos")
        take.tap()
        Thread.sleep(forTimeInterval: 4)
        attach("camera-open")
        let shutter = app.buttons["camera.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 15), "no shutter")
        for shot in 1...6 {
            shutter.tap()
            Thread.sleep(forTimeInterval: 7)
            XCTAssertEqual(app.state, .runningForeground, "the app stopped after shot \(shot)")
            print("[camera-qa] shot \(shot) survived")
        }
        let count = app.descendants(matching: .any)["camera.count"]
        print("[camera-qa] count label: \(count.exists ? count.label : "missing")")
        attach("after-shots")
    }
}
