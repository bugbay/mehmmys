import XCTest
@testable import Mehmmy

@MainActor
final class JoinLinkTests: XCTestCase {
    func testParsesInviteLinks() {
        XCTAssertEqual(JoinLink.code(from: URL(string: "https://mehmmys.app/join/abc234")!), "ABC234")
        XCTAssertEqual(JoinLink.code(from: URL(string: "https://www.mehmmys.app/join/MHM23K/")!), "MHM23K")
        XCTAssertNil(JoinLink.code(from: URL(string: "https://mehmmys.app/privacy")!))
        XCTAssertNil(JoinLink.code(from: URL(string: "https://evil.example/join/ABC234")!))
        XCTAssertNil(JoinLink.code(from: URL(string: "https://mehmmys.app/join/")!))
    }

    func testLinkIsHeldUntilTheUserIsReady() {
        let state = AppState.sample(onboarded: false)
        state.handle(url: URL(string: "https://mehmmys.app/join/ABC234")!)
        XCTAssertEqual(state.pendingJoinCode, "ABC234")
    }
}
