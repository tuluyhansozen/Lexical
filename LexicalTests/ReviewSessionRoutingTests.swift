import XCTest
@testable import Lexical

final class ReviewSessionRoutingTests: XCTestCase {
    func testRouteToReviewSelectsRecallTabAndIncrementsStartSignal() {
        let routed = ReviewSessionRouting.routeToReview(
            reviewStartSignal: 4
        )

        XCTAssertEqual(routed.selectedTab, ReviewSessionRouting.recallTabIndex)
        XCTAssertEqual(routed.reviewStartSignal, 5)
    }

    func testRouteToPromptKeepsStartSignalUntouched() {
        let routed = ReviewSessionRouting.routeToPrompt(
            reviewStartSignal: 8
        )

        XCTAssertEqual(routed.selectedTab, ReviewSessionRouting.recallTabIndex)
        XCTAssertEqual(routed.reviewStartSignal, 8)
    }
}
