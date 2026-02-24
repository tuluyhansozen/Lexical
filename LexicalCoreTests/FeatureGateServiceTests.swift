import Foundation
import SwiftData
import XCTest
@testable import LexicalCore

@MainActor
final class FeatureGateServiceTests: XCTestCase {
    private let activeUserDefaultsKey = UserProfile.activeUserDefaultsKey

    override func setUp() {
        super.setUp()
        clearActiveUserDefaults()
    }

    override func tearDown() {
        clearActiveUserDefaults()
        super.tearDown()
    }

    func testFreeTierWeeklyArticleLimitAllowsOnlyOnePerWindow() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "gate.free.article")
        let profile = UserProfile(userId: userId)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)

        let service = FeatureGateService()
        let now = Date(timeIntervalSince1970: 1000)

        XCTAssertTrue(try service.canGenerateArticle(modelContext: context, now: now))
        XCTAssertTrue(try service.recordArticleGeneration(modelContext: context, now: now))
        XCTAssertFalse(try service.canGenerateArticle(modelContext: context, now: now))

        let snapshot = try service.articleQuotaSnapshot(modelContext: context, now: now)
        XCTAssertEqual(snapshot.remaining, 0)
        XCTAssertEqual(snapshot.limit, 1)
        XCTAssertFalse(snapshot.isUnlimited)

        let afterWindow = now.addingTimeInterval(TimeInterval(8 * 24 * 60 * 60))
        XCTAssertTrue(try service.canGenerateArticle(modelContext: context, now: afterWindow))
    }

    func testPremiumTierHasUnlimitedArticlesAndPersonalizedFSRSMode() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "gate.premium")
        let profile = UserProfile(userId: userId, lexicalRank: 6_000, easyRatingVelocity: 0.8)
        profile.applySubscriptionTier(SubscriptionTier.premium, source: EntitlementSource.appStore)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)

        let service = FeatureGateService()
        let now = Date(timeIntervalSince1970: 2000)

        XCTAssertTrue(try service.canGenerateArticle(modelContext: context, now: now))
        XCTAssertTrue(try service.recordArticleGeneration(modelContext: context, now: now))
        XCTAssertTrue(try service.recordArticleGeneration(modelContext: context, now: now.addingTimeInterval(60)))
        XCTAssertTrue(try service.recordArticleGeneration(modelContext: context, now: now.addingTimeInterval(120)))

        let snapshot = try service.articleQuotaSnapshot(modelContext: context, now: now)
        XCTAssertTrue(snapshot.isUnlimited)
        XCTAssertEqual(service.activeFSRSMode(modelContext: context), .personalized)
        XCTAssertGreaterThan(service.fsrsRequestRetention(modelContext: context), 0.9)
    }

    func testFreeTierWidgetCapIsOneProfile() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "gate.free.widget")
        context.insert(UserProfile(userId: userId))
        try context.save()
        setActiveUser(userId)

        let service = FeatureGateService()
        XCTAssertTrue(try service.canCreateAdditionalWidgetProfile(modelContext: context, currentCount: 0))
        XCTAssertFalse(try service.canCreateAdditionalWidgetProfile(modelContext: context, currentCount: 1))

        try service.setActiveWidgetProfileCount(1, modelContext: context)
        XCTAssertFalse(try service.canCreateAdditionalWidgetProfile(modelContext: context))
    }

    func testFreeTierStatsDepthIsWeekOnly() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "gate.free.stats")
        context.insert(UserProfile(userId: userId))
        try context.save()
        setActiveUser(userId)

        let service = FeatureGateService()
        let available = service.availableStatsPeriods(modelContext: context)

        XCTAssertEqual(available, [.week, .month, .year])
        XCTAssertTrue(service.canAccessStatsPeriod(.week, modelContext: context))
        XCTAssertTrue(service.canAccessStatsPeriod(.month, modelContext: context))
        XCTAssertTrue(service.canAccessStatsPeriod(.year, modelContext: context))
    }

    func testPremiumTierStatsDepthIncludesAllPeriods() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "gate.premium.stats")
        let profile = UserProfile(userId: userId)
        profile.applySubscriptionTier(.premium, source: .appStore)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)

        let service = FeatureGateService()
        let available = service.availableStatsPeriods(modelContext: context)

        XCTAssertEqual(available, StatsPeriod.allCases)
        XCTAssertTrue(service.canAccessStatsPeriod(.week, modelContext: context))
        XCTAssertTrue(service.canAccessStatsPeriod(.month, modelContext: context))
        XCTAssertTrue(service.canAccessStatsPeriod(.year, modelContext: context))
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV6.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func setActiveUser(_ userId: String) {
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.set(userId, forKey: activeUserDefaultsKey)
    }

    private func clearActiveUserDefaults() {
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.removeObject(forKey: activeUserDefaultsKey)
    }

    private func uniqueUserID(prefix: String) -> String {
        "\(prefix).\(UUID().uuidString)"
    }
}
