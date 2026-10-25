import XCTest

/// Opens shared reels from a conversation and tries to get to another reel by swiping and
/// by waiting for auto-advance. Runs against `UITests/Fixtures` (start it with `UITests/run.sh`),
/// which opens each shared reel in a different way Instagram's web client might.
final class ReelSwipeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // On a real iPhone the fixture runs on the Mac: run.sh passes its address as TEST_RUNNER_REELLESS_ORIGIN.
        let origin = ProcessInfo.processInfo.environment["REELLESS_ORIGIN"] ?? "http://localhost:8765"
        app.launchArguments = ["-ReelLessOrigin", origin]
        app.launch()
        allowLocalNetworkIfAsked()
        let thread = app.links["Thread with Ana"]
        XCTAssertTrue(thread.waitForExistence(timeout: 15), "inbox fixture did not load; is UITests/run.sh serving it?")
        thread.tap()
        XCTAssertTrue(app.staticTexts["MSG-1"].waitForExistence(timeout: 10))
    }

    func testChatStillScrolls() {
        XCTAssertFalse(isOnScreen("MSG-40"))
        for _ in 0..<4 { app.swipeUp(velocity: .fast) }
        XCTAssertTrue(isOnScreen("MSG-40") || isOnScreen("MSG-35"), "the chat itself must still scroll")
    }

    func testSharedReelOpenedByLinkCannotBeSwiped() {
        app.links["Shared reel A"].tap()
        assertOnlyFirstReelReachable()
    }

    func testSharedReelOpenedInPageWithURLChangeCannotBeSwiped() {
        app.buttons["Shared reel B"].tap()
        assertOnlyFirstReelReachable()
    }

    func testSharedReelOpenedInPageWithoutURLChangeCannotBeSwiped() {
        app.buttons["Shared reel C"].tap()
        assertOnlyFirstReelReachable()
    }

    func testSharedReelWithGestureCarouselCannotBeSwiped() {
        app.buttons["Shared reel D"].tap()
        assertOnlyFirstReelReachable()
    }

    func testFeedTabsAreHidden() {
        for tab in ["Home", "Explore", "Reels"] {
            XCTAssertFalse(app.links[tab].exists, "\(tab) tab should be hidden")
        }
        XCTAssertTrue(app.links["Messages"].exists)
    }

    // MARK: Helpers

    /// iOS asks once before an app may reach a device on the local network (the Mac serving fixtures).
    private func allowLocalNetworkIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
    }

    /// The shared reel must be watchable, and no swipe or wait may reveal the next one,
    /// neither in the viewer nor in the conversation after closing it.
    private func assertOnlyFirstReelReachable(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitUntilOnScreen("REEL-1", timeout: 10), "the shared reel should be watchable", file: file, line: line)
        tryToReachNextReel()
        assertNoOtherReel("in the viewer", file: file, line: line)

        let done = app.buttons["Done"]
        if done.exists {
            done.tap()
            sleep(1)
            if isOnScreen("REEL-1") {
                tryToReachNextReel()
            }
            assertNoOtherReel("in the conversation after closing the viewer", file: file, line: line)
        }
    }

    private func tryToReachNextReel() {
        for velocity in [XCUIGestureVelocity.slow, .default, .fast] {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)),
                        withVelocity: velocity, thenHoldForDuration: 0.1)
        }
        app.swipeUp(velocity: .fast)
        // Fixtures auto-advance after 2.5 s, like a reel that ends.
        sleep(4)
    }

    private func assertNoOtherReel(_ context: String, file: StaticString, line: UInt) {
        for n in 2...5 {
            XCTAssertFalse(isOnScreen("REEL-\(n)"), "swiped or advanced to REEL-\(n) \(context)", file: file, line: line)
        }
    }

    private func waitUntilOnScreen(_ label: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isOnScreen(label) { return true }
            usleep(250_000)
        }
        return false
    }

    /// Visible means at least 40 pt of the label's frame lies inside the screen.
    private func isOnScreen(_ label: String) -> Bool {
        let screen = app.windows.firstMatch.frame
        return app.staticTexts.matching(identifier: label).allElementsBoundByIndex.contains { element in
            let visible = element.frame.intersection(screen)
            return !visible.isNull && visible.height >= 20 && visible.width >= 20
        }
    }
}
