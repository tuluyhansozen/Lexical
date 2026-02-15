import Foundation
import XCTest
@testable import LexicalCore

final class ArticlePromptPlannerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ArticlePromptPlannerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        if let suiteName {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPlannerBuildsConcreteTopicAndAngleForMultiInterestUser() {
        let planner = ArticlePromptPlanner(
            memoryStore: ArticlePromptMemoryStore(defaults: defaults)
        )
        let profile = InterestProfile(selectedTags: ["Technology", "Science", "Productivity", "Business"])
        let recent = [
            GeneratedArticle(
                title: "How Attention Shapes Language Memory",
                content: "Short body",
                targetWords: ["attention", "memory"],
                category: "Science",
                difficultyScore: 0.4
            )
        ]

        let plan = planner.buildPlan(
            profile: profile,
            recentArticles: recent,
            targetWords: ["context", "insight", "resilient"],
            userId: "planner.test.user"
        )

        XCTAssertFalse(plan.category.isEmpty)
        XCTAssertFalse(plan.topic.isEmpty)
        XCTAssertFalse(plan.angleName.isEmpty)
        XCTAssertFalse(plan.angleDirective.isEmpty)
        XCTAssertFalse(plan.openingHook.isEmpty)
        XCTAssertNotEqual(plan.topic.lowercased(), plan.category.lowercased())
    }

    func testPlannerRotatesTopicOrAngleAfterRecordingUsage() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let planner = ArticlePromptPlanner(
            memoryStore: ArticlePromptMemoryStore(defaults: defaults),
            nowProvider: { now }
        )
        let profile = InterestProfile(selectedTags: ["Technology", "Science", "Productivity", "Business"])

        let first = planner.buildPlan(
            profile: profile,
            recentArticles: [],
            targetWords: ["context", "insight", "resilient"],
            userId: "planner.rotate.user"
        )
        planner.recordUsage(plan: first, userId: "planner.rotate.user")

        let second = planner.buildPlan(
            profile: profile,
            recentArticles: [],
            targetWords: ["context", "insight", "resilient"],
            userId: "planner.rotate.user"
        )

        XCTAssertTrue(first.topic != second.topic || first.angleName != second.angleName)
    }
}
