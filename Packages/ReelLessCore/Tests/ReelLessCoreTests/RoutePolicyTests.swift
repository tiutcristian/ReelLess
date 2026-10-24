import XCTest
@testable import ReelLessCore

final class RoutePolicyTests: XCTestCase {
    private func policy() throws -> RoutePolicy { try RoutePolicy(pack: RulePack.bundled()) }
    private func decide(_ s: String) throws -> RouteDecision { try policy().decide(URL(string: s)!) }

    func testAllows() throws {
        for s in ["https://www.instagram.com/direct/inbox/",
                  "https://www.instagram.com/direct/t/1234567/",
                  "https://www.instagram.com/accounts/login/",
                  "https://www.instagram.com/challenge/abc/",
                  "about:blank"] {
            XCTAssertEqual(try decide(s), .allow, s)
        }
    }

    func testFeedLikeRoutesRedirect() throws {
        for s in ["https://www.instagram.com/", "https://www.instagram.com/explore/",
                  "https://www.instagram.com/reels/", "https://www.instagram.com/stories/",
                  "https://www.instagram.com/someuser/", "https://www.instagram.com/unknown/path"] {
            XCTAssertEqual(try decide(s), .redirectToInbox, s)
        }
    }

    func testSharedItemsAreQuarantined() throws {
        for s in ["https://www.instagram.com/reel/Cabc_123/", "https://www.instagram.com/p/Cabc-123",
                  "https://www.instagram.com/tv/Cabc123/", "https://www.instagram.com/reels/Cabc123/",
                  "https://www.instagram.com/stories/user/3141592653589793/"] {
            let url = URL(string: s)!
            XCTAssertEqual(try policy().decide(url), .quarantine(url), s)
        }
    }

    func testExternalLinks() throws {
        XCTAssertEqual(try decide("https://example.com/x"), .external(URL(string: "https://example.com/x")!))
        XCTAssertEqual(try decide("https://l.instagram.com/?u=https%3A%2F%2Fexample.com%2Fa&e=1"),
                       .external(URL(string: "https://example.com/a")!))
        XCTAssertEqual(try decide("https://l.instagram.com/?u=https%3A%2F%2Fwww.instagram.com%2Freels%2F"), .block)
        XCTAssertEqual(try decide("instagram://reels"), .block)
    }

    func testViewerOnlyAllowsOwnItem() {
        let item = URL(string: "https://www.instagram.com/reel/Cabc/")!
        XCTAssertTrue(RoutePolicy.allowsInViewer(URL(string: "https://www.instagram.com/reel/Cabc")!, item: item))
        XCTAssertFalse(RoutePolicy.allowsInViewer(URL(string: "https://www.instagram.com/reel/Cxyz/")!, item: item))
        XCTAssertFalse(RoutePolicy.allowsInViewer(URL(string: "https://www.instagram.com/reels/")!, item: item))
    }

    func testBridgeParsing() {
        XCTAssertNotNil(BridgeMessage.parseRoute(["type": "route", "url": "https://www.instagram.com/explore/"]))
        XCTAssertNil(BridgeMessage.parseRoute(["type": "eval", "url": "https://x.com"]))
        XCTAssertNil(BridgeMessage.parseRoute("route"))
    }

    func testScriptsEmbedPack() throws {
        let pack = try RulePack.bundled()
        XCTAssertTrue(Shield.mainScript(pack: pack).contains("/explore"))
        XCTAssertTrue(Shield.viewerScript(pack: pack).contains("overflow"))
    }
}
