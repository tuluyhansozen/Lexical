import Foundation

struct ReviewSessionRouting {
    static let recallTabIndex = 2

    static func routeToReview(
        selectedTab: Int,
        reviewStartSignal: UInt64
    ) -> (selectedTab: Int, reviewStartSignal: UInt64) {
        (recallTabIndex, reviewStartSignal &+ 1)
    }

    static func routeToPrompt(
        selectedTab: Int,
        reviewStartSignal: UInt64
    ) -> (selectedTab: Int, reviewStartSignal: UInt64) {
        (recallTabIndex, reviewStartSignal)
    }
}
