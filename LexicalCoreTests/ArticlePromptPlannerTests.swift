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

    func testPlannerProvidesNicheTopicsForCustomInterestTags() {
        let planner = ArticlePromptPlanner(
            memoryStore: ArticlePromptMemoryStore(defaults: defaults)
        )
        let profile = InterestProfile(selectedTags: ["Aviation"])

        let plan = planner.buildPlan(
            profile: profile,
            recentArticles: [],
            targetWords: ["checklist", "safety", "workflow"],
            userId: "planner.niche.user"
        )

        XCTAssertEqual(plan.category, "Nature")
        XCTAssertTrue(
            plan.topic.localizedCaseInsensitiveContains("flight") ||
            plan.topic.localizedCaseInsensitiveContains("aviation") ||
            plan.topic.localizedCaseInsensitiveContains("checklist") ||
            plan.topic.localizedCaseInsensitiveContains("crew")
        )
    }

    func testNoveltyScorerPrefersSemanticallyRelatedCorpus() {
        let scorer = ArticleNoveltyScorer()
        let candidate = "retrieval-first habit loops for language practice"
        let nearCorpus = [
            "habit loops and retrieval practice for language learners",
            "how to structure daily recall routines"
        ]
        let farCorpus = [
            "marine biodiversity under climate stress",
            "architectural lighting strategies for galleries"
        ]

        let near = scorer.blendedSimilarity(of: candidate, against: nearCorpus)
        let far = scorer.blendedSimilarity(of: candidate, against: farCorpus)

        XCTAssertGreaterThan(near, far)
        XCTAssertGreaterThan(near, 0.35)
        XCTAssertLessThan(far, 0.30)
    }
}
