import Foundation
import SwiftData
import XCTest
@testable import LexicalCore

@MainActor
final class StatsServiceTests: XCTestCase {
    private let activeUserDefaultsKey = UserProfile.activeUserDefaultsKey

    override func setUp() {
        super.setUp()
        clearActiveUserDefaults()
    }

    override func tearDown() {
        clearActiveUserDefaults()
        super.tearDown()
    }

    func testRetentionUsesFirstInteractiveAttemptPerLemmaDayAndIgnoresImplicit() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "stats.retention")
        context.insert(UserProfile(userId: userId))
        setActiveUser(userId)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let day = Calendar.current.startOfDay(for: now)

        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "alpha",
                grade: 3,
                reviewDate: day.addingTimeInterval(9 * 3600),
                durationMs: 250,
                scheduledDays: 0.2,
                reviewState: ReviewEvent.implicitExposureState
            )
        )
        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "alpha",
                grade: 1,
                reviewDate: day.addingTimeInterval(10 * 3600),
                durationMs: 0,
                scheduledDays: 1.0,
                reviewState: ReviewEvent.sessionReviewState(for: 1)
            )
        )
        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "alpha",
                grade: 3,
                reviewDate: day.addingTimeInterval(10 * 3600 + 60),
                durationMs: 0,
                scheduledDays: 1.2,
                reviewState: ReviewEvent.sessionReviewState(for: 3)
            )
        )
        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "beta",
                grade: 3,
                reviewDate: day.addingTimeInterval(11 * 3600),
                durationMs: 0,
                scheduledDays: 2.0,
                reviewState: ReviewEvent.reviewState(for: 3)
            )
        )
        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "gamma",
                grade: 2,
                reviewDate: day.addingTimeInterval(12 * 3600),
                durationMs: 0,
                scheduledDays: 1.5,
                reviewState: ReviewEvent.sessionReviewState(for: 2)
            )
        )
        try context.save()

        let service = StatsService(modelContext: context)
        let retention = service.calculateRetentionRate(period: .last30)
        XCTAssertEqual(retention, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testAcquiredCountsOnlyFirstDurableExplicitSuccessInPeriod() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "stats.acquired")
        context.insert(UserProfile(userId: userId))
        setActiveUser(userId)

        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -40, to: now)!
        let recentDate = Calendar.current.date(byAdding: .day, value: -5, to: now)!

        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "old-lemma",
                grade: 3,
                reviewDate: oldDate,
                durationMs: 0,
                scheduledDays: 3.0,
                reviewState: ReviewEvent.reviewState(for: 3)
            )
        )
        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "new-lemma",
                grade: 4,
                reviewDate: recentDate,
                durationMs: 0,
                scheduledDays: 4.0,
                reviewState: ReviewEvent.reviewState(for: 4)
            )
        )
        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "session-only",
                grade: 4,
                reviewDate: recentDate,
                durationMs: 0,
                scheduledDays: 1.0,
                reviewState: ReviewEvent.sessionReviewState(for: 4)
            )
        )
        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "implicit-only",
                grade: 3,
                reviewDate: recentDate,
                durationMs: 200,
                scheduledDays: 0.2,
                reviewState: ReviewEvent.implicitExposureState
            )
        )
        try context.save()

        let service = StatsService(modelContext: context)
        XCTAssertEqual(service.fetchAcquired(period: .last30), 1)
    }

    func testStreakIgnoresImplicitOnlyToday() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "stats.streak")
        context.insert(UserProfile(userId: userId))
        setActiveUser(userId)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "noise",
                grade: 3,
                reviewDate: today.addingTimeInterval(10 * 3600),
                durationMs: 200,
                scheduledDays: 0.2,
                reviewState: ReviewEvent.implicitExposureState
            )
        )
        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "focus1",
                grade: 3,
                reviewDate: yesterday.addingTimeInterval(10 * 3600),
                durationMs: 0,
                scheduledDays: 1.0,
                reviewState: ReviewEvent.reviewState(for: 3)
            )
        )
        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "focus2",
                grade: 2,
                reviewDate: twoDaysAgo.addingTimeInterval(10 * 3600),
                durationMs: 0,
                scheduledDays: 1.0,
                reviewState: ReviewEvent.sessionReviewState(for: 2)
            )
        )
        try context.save()

        let service = StatsService(modelContext: context)
        XCTAssertEqual(service.calculateStreak(), 2)
    }

    func testProjectedForgettingCurveUsesFSRSShape() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "stats.curve")
        context.insert(UserProfile(userId: userId))
        setActiveUser(userId)

        let state = UserWordState(
            userId: userId,
            lemma: "stability",
            status: .learning,
            stability: 10.0,
            difficulty: 3.0,
            retrievability: 1.0,
            reviewCount: 3
        )
        context.insert(state)
        try context.save()

        let service = StatsService(modelContext: context)
        let curve = service.projectedForgettingCurve()

        XCTAssertEqual(curve.count, 10)
        XCTAssertEqual(curve[0].1, 100.0, accuracy: 0.0001)

        let expectedDay1 = 100.0 * pow(1 + 19 * 1.0 / 10.0, -1)
        XCTAssertEqual(curve[1].1, expectedDay1, accuracy: 0.0001)
        XCTAssertGreaterThan(curve[1].1, curve[2].1)
    }

    func testScenarioDailyRoutineThirtyDaysSnapshot() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "stats.scenario")
        context.insert(UserProfile(userId: userId))
        setActiveUser(userId)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dayOffset in 0..<30 {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let dayKey = 30 - dayOffset

            // Simulate 3 article words added+reviewed with durable explicit success.
            for index in 1...3 {
                let lemma = "article-\(dayKey)-\(index)"
                context.insert(
                    UserWordState(
                        userId: userId,
                        lemma: lemma,
                        status: .learning,
                        stability: 120.0,
                        difficulty: 3.0,
                        retrievability: 0.9,
                        reviewCount: 1
                    )
                )
                context.insert(
                    ReviewEvent(
                        userId: userId,
                        lemma: lemma,
                        grade: 3,
                        reviewDate: day.addingTimeInterval(TimeInterval(8 + index) * 3600),
                        durationMs: 0,
                        scheduledDays: 1.0,
                        reviewState: ReviewEvent.reviewState(for: 3)
                    )
                )
            }

            // Simulate 2 additional reviewed words (session interactions).
            context.insert(
                ReviewEvent(
                    userId: userId,
                    lemma: "carry-\(dayKey)-1",
                    grade: 2,
                    reviewDate: day.addingTimeInterval(12 * 3600),
                    durationMs: 0,
                    scheduledDays: 1.0,
                    reviewState: ReviewEvent.sessionReviewState(for: 2)
                )
            )
            context.insert(
                ReviewEvent(
                    userId: userId,
                    lemma: "carry-\(dayKey)-2",
                    grade: 1,
                    reviewDate: day.addingTimeInterval(13 * 3600),
                    durationMs: 0,
                    scheduledDays: 1.0,
                    reviewState: ReviewEvent.sessionReviewState(for: 1)
                )
            )

            // Simulate 1 notification suggested word added to deck (no review yet).
            context.insert(
                UserWordState(
                    userId: userId,
                    lemma: "notif-\(dayKey)",
                    status: .learning
                )
            )
        }
        try context.save()

        let service = StatsService(modelContext: context)
        let snapshot = service.loadSnapshot(period: .last30)

        // 30 days * 3 durable explicit successes/day
        XCTAssertEqual(snapshot.acquiredCount, 90)
        // Per day 3 successful out of 5 interactive attempts => 60%
        XCTAssertEqual(snapshot.retentionRate, 0.6, accuracy: 0.0001)
        XCTAssertEqual(snapshot.streak, 30)
        XCTAssertEqual(snapshot.heatmap.count, 30)
        XCTAssertTrue(snapshot.heatmap.allSatisfy { $0.count == 5 })

        print(
            """
            SCENARIO_SNAPSHOT \
            acquired=\(snapshot.acquiredCount) \
            retention=\(Int((snapshot.retentionRate * 100).rounded()))% \
            streak=\(snapshot.streak) \
            heatmapDaily=\(snapshot.heatmap.first?.count ?? 0) \
            curveDay0=\(String(format: "%.1f", snapshot.curvePoints[0].1)) \
            curveDay1=\(String(format: "%.1f", snapshot.curvePoints[1].1)) \
            curveDay9=\(String(format: "%.1f", snapshot.curvePoints[9].1))
            """
        )
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV5.models)
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
