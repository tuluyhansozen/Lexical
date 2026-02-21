import XCTest
@testable import Lexical

final class ReviewSessionRoutingTests: XCTestCase {
    func testRouteToReviewSelectsRecallTabAndIncrementsStartSignal() {
        let routed = ReviewSessionRouting.routeToReview(
            selectedTab: 0,
            reviewStartSignal: 4
        )

        XCTAssertEqual(routed.selectedTab, ReviewSessionRouting.recallTabIndex)
        XCTAssertEqual(routed.reviewStartSignal, 5)
    }

    func testRouteToPromptKeepsStartSignalUntouched() {
        let routed = ReviewSessionRouting.routeToPrompt(
            selectedTab: 1,
            reviewStartSignal: 8
        )

        XCTAssertEqual(routed.selectedTab, ReviewSessionRouting.recallTabIndex)
        XCTAssertEqual(routed.reviewStartSignal, 8)
    }
}
