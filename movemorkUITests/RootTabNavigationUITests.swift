//
//  RootTabNavigationUITests.swift
//  movemorkUITests
//
//  Root-tab switching (1.4.1) on the DEBUG fixture (`-MMRichQA tabs`: the production MMRootTabHost and dock
//  over fixture pages), so it runs without an account. Live signed-in coverage stays in TabReselectUITests.
//
//  Optional runner environment (internal MM_NAV_LAB builds): TEST_RUNNER_MM_NAV_VARIANT=A|B|C,
//  TEST_RUNNER_MM_NAV_DOCK=classic|pill. Reduce Motion follows the simulator setting.
//

import XCTest

final class RootTabNavigationUITests: XCTestCase {
    private let titles = ["Proof": "YOUR PROOF", "Reports": "Your proof records", "Account": "Your account"]

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-MMRichQA", "tabs"]
        let env = ProcessInfo.processInfo.environment
        if let v = env["MM_NAV_VARIANT"], !v.isEmpty { args += ["-MMNavVariant", v] }
        if let d = env["MM_NAV_DOCK"], !d.isEmpty { args += ["-MMNavDock", d] }
        app.launchArguments = args + extra
        app.launch()
        XCTAssertTrue(app.buttons["Proof"].waitForExistence(timeout: 15))
        return app
    }

    private func title(_ app: XCUIApplication, _ tab: String) -> XCUIElement {
        app.staticTexts[titles[tab]!].firstMatch
    }

    /// Once settled only the destination page is in the accessibility tree, and only its dock item is selected.
    private func assertSettled(on tab: String, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(title(app, tab).waitForExistence(timeout: 3), "\(tab) title visible", file: file, line: line)
        XCTAssertTrue(title(app, tab).isHittable, "\(tab) title hittable", file: file, line: line)
        for other in titles.keys where other != tab {
            XCTAssertFalse(title(app, other).exists, "\(other) is out of the accessibility tree while \(tab) shows", file: file, line: line)
        }
        for item in titles.keys {
            let button = app.buttons[item].firstMatch
            XCTAssertTrue(button.exists, "dock item \(item)", file: file, line: line)
            XCTAssertEqual(button.isSelected, item == tab, "\(item) selected trait", file: file, line: line)
        }
    }

    func test01_EveryPairLandsCleanly() {
        let app = launch()
        assertSettled(on: "Proof", app)
        // P→R, R→A, A→P, P→A, A→R, R→P.
        for tab in ["Reports", "Account", "Proof", "Account", "Reports", "Proof"] {
            app.buttons[tab].firstMatch.tap()
            assertSettled(on: tab, app)
        }
    }

    func test02_RapidTapsSettleOnLastTap() {
        let app = launch()
        // Visit every page once so later taps switch between live pages.
        for tab in ["Reports", "Account", "Proof"] { app.buttons[tab].firstMatch.tap() }
        let burst = ["Reports", "Account", "Proof", "Reports", "Account"]
        for tab in burst { app.buttons[tab].firstMatch.tap() }
        assertSettled(on: burst.last!, app)
        // Mid-burst reselect of the tab already selected must not navigate anywhere.
        app.buttons["Account"].firstMatch.tap()
        app.buttons["Proof"].firstMatch.tap()
        app.buttons["Proof"].firstMatch.tap()
        assertSettled(on: "Proof", app)
    }

    func test03_ReselectScrollsToTop() {
        let app = launch()
        for tab in ["Proof", "Account"] {
            app.buttons[tab].firstMatch.tap()
            let header = title(app, tab)
            XCTAssertTrue(header.waitForExistence(timeout: 3))
            let top = header.frame.minY
            app.swipeUp()
            sleep(1)
            XCTAssertLessThan(header.frame.minY, top - 40, "\(tab) scrolled")
            app.buttons[tab].firstMatch.tap()
            sleep(1)
            XCTAssertEqual(header.frame.minY, top, accuracy: 2, "\(tab) reselect scrolled to top")
        }
    }

    func test04_ScrollAndNavigationSurviveSwitches() {
        let app = launch()
        // Proof scrolled.
        let proofHeader = title(app, "Proof")
        app.swipeUp()
        sleep(1)
        let proofScrolled = proofHeader.frame.minY
        // Account pushed.
        app.buttons["Account"].firstMatch.tap()
        XCTAssertTrue(title(app, "Account").waitForExistence(timeout: 3))
        app.buttons["Contact support"].firstMatch.tap()
        let pushed = app.staticTexts["Support fixture"].firstMatch
        XCTAssertTrue(pushed.waitForExistence(timeout: 3))
        // Away and back: both survive.
        app.buttons["Reports"].firstMatch.tap()
        XCTAssertTrue(title(app, "Reports").waitForExistence(timeout: 3))
        XCTAssertFalse(pushed.exists, "Account's pushed screen is hidden while Reports shows")
        app.buttons["Proof"].firstMatch.tap()
        XCTAssertTrue(proofHeader.waitForExistence(timeout: 3))
        XCTAssertEqual(proofHeader.frame.minY, proofScrolled, accuracy: 2, "Proof kept its scroll")
        app.buttons["Account"].firstMatch.tap()
        XCTAssertTrue(pushed.waitForExistence(timeout: 3), "Account kept its navigation stack")
        // Reselect on a pushed tab pops to its root.
        app.buttons["Account"].firstMatch.tap()
        XCTAssertTrue(title(app, "Account").waitForExistence(timeout: 3))
        XCTAssertTrue(waitUntilGone(pushed, timeout: 3), "Reselect popped Account to its root")
    }

    func test05_DockAccessibility() {
        let app = launch()
        let screen = app.windows.firstMatch.frame
        for (tab, id) in [("Proof", "tab.proof"), ("Reports", "tab.reports"), ("Account", "tab.account")] {
            let byLabel = app.buttons[tab].firstMatch
            XCTAssertTrue(byLabel.exists, "label \(tab)")
            XCTAssertTrue(app.buttons[id].firstMatch.exists, "identifier \(id)")
            XCTAssertTrue(byLabel.isHittable, "\(tab) hittable")
            XCTAssertGreaterThanOrEqual(byLabel.frame.height, 44, "\(tab) 44 pt target")
            XCTAssertGreaterThanOrEqual(byLabel.frame.width, 44, "\(tab) 44 pt target")
            XCTAssertTrue(screen.contains(byLabel.frame), "\(tab) on screen")
        }
        app.buttons["Account"].firstMatch.tap()
        assertSettled(on: "Account", app)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "selected == true")).count, 1, "exactly one selected dock item")
    }

    func test06_LargestDynamicType() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let screen = app.windows.firstMatch.frame
        for tab in ["Reports", "Account", "Proof", "Account"] {
            app.buttons[tab].firstMatch.tap()
            XCTAssertTrue(app.buttons[tab].firstMatch.isSelected, "\(tab) selected at AX XXXL")
            for item in titles.keys {
                let b = app.buttons[item].firstMatch
                XCTAssertTrue(b.isHittable, "\(item) hittable at AX XXXL")
                XCTAssertTrue(screen.contains(b.frame), "\(item) on screen at AX XXXL")
            }
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "tabs-ax-xxxl"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            usleep(100_000)
        }
        return !element.exists
    }
}
