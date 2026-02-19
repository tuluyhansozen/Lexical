import XCTest
import SwiftData
import LexicalCore
@testable import Lexical

@MainActor
final class SessionManagerFallbackPracticeTests: XCTestCase {
    func testNoDueShowsFallbackAction() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = UserProfile.resolveActiveProfile(modelContext: context).userId
        let now = Date()

        try setPremium(modelContext: context)

        seedLexeme("future", modelContext: context)
        seedState(
            userId: userId,
            lemma: "future",
            status: .learning,
            nextReviewDate: now.addingTimeInterval(60 * 60),
            stability: 4.0,
            reviewCount: 2,
            modelContext: context
        )
        try context.save()

        let manager = SessionManager(modelContext: context)
        manager.startSession()

        XCTAssertTrue(manager.isSessionComplete)
        XCTAssertTrue(manager.canStartFallbackPractice)
        XCTAssertEqual(manager.sessionMode, .dueOnly)
        XCTAssertTrue(manager.queue.isEmpty)
    }

    func testNoDueFreeUserCannotStartFallbackPractice() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = UserProfile.resolveActiveProfile(modelContext: context).userId
        let now = Date()

        seedLexeme("futurefree", modelContext: context)
        seedState(
            userId: userId,
            lemma: "futurefree",
            status: .learning,
            nextReviewDate: now.addingTimeInterval(60 * 60),
            stability: 4.0,
            reviewCount: 2,
            modelContext: context
        )
        try context.save()

        let manager = SessionManager(modelContext: context)
        manager.startSession()

        XCTAssertFalse(manager.isPremiumUser)
        XCTAssertFalse(manager.canStartFallbackPractice)
        XCTAssertTrue(manager.isSessionComplete)
    }

    func testFallbackSelectsLearningNewNonDueFirst() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = UserProfile.resolveActiveProfile(modelContext: context).userId
        let now = Date()

        try setPremium(modelContext: context)

        seedLexeme("alpha", modelContext: context)
        seedLexeme("beta", modelContext: context)
        seedLexeme("charlie", modelContext: context)
        seedLexeme("knownword", modelContext: context)
        seedLexeme("ignoredword", modelContext: context)

        seedState(
            userId: userId,
            lemma: "alpha",
            status: .learning,
            nextReviewDate: now.addingTimeInterval(60 * 60),
            stability: 5.0,
            reviewCount: 2,
            modelContext: context
        )
        seedState(
            userId: userId,
            lemma: "beta",
            status: .new,
            nextReviewDate: now.addingTimeInterval(60 * 60),
            stability: 2.0,
            reviewCount: 0,
            modelContext: context
        )
        seedState(
            userId: userId,
            lemma: "charlie",
            status: .learning,
            nextReviewDate: now.addingTimeInterval(30 * 60),
            stability: 9.0,
            reviewCount: 1,
            modelContext: context
        )
        seedState(
            userId: userId,
            lemma: "knownword",
            status: .known,
            nextReviewDate: now.addingTimeInterval(10 * 60),
            stability: 1.0,
            reviewCount: 10,
            modelContext: context
        )
        seedState(
            userId: userId,
            lemma: "ignoredword",
            status: .ignored,
            nextReviewDate: now.addingTimeInterval(5 * 60),
            stability: 1.0,
            reviewCount: 3,
            modelContext: context
        )
        try context.save()

        let manager = SessionManager(modelContext: context)
        manager.startFallbackPracticeSession()

        XCTAssertEqual(manager.sessionMode, .fallbackPractice)
        XCTAssertEqual(manager.queue.map(\.lemma), ["charlie", "beta", "alpha"])
    }

    func testFallbackUsesKnownBackupWhenNoLearningNew() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = UserProfile.resolveActiveProfile(modelContext: context).userId
        let now = Date()

        try setPremium(modelContext: context)

        seedLexeme("k1", modelContext: context)
        seedLexeme("k2", modelContext: context)

        seedState(
            userId: userId,
            lemma: "k1",
            status: .known,
            nextReviewDate: now.addingTimeInterval(2 * 60 * 60),
            stability: 70.0,
            reviewCount: 8,
            modelContext: context
        )
        seedState(
            userId: userId,
            lemma: "k2",
            status: .known,
            nextReviewDate: now.addingTimeInterval(60 * 60),
            stability: 50.0,
            reviewCount: 6,
            modelContext: context
        )
        try context.save()

        let manager = SessionManager(modelContext: context)
        manager.startFallbackPracticeSession()

        XCTAssertEqual(manager.queue.map(\.lemma), ["k2", "k1"])
        XCTAssertTrue(manager.queue.allSatisfy { $0.status == .known })
    }

    func testFallbackQueueSortedSoonestThenLowerStability() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = UserProfile.resolveActiveProfile(modelContext: context).userId
        let now = Date()

        try setPremium(modelContext: context)

        seedLexeme("delta", modelContext: context)
        seedLexeme("echo", modelContext: context)
        seedLexeme("foxtrot", modelContext: context)

        seedState(
            userId: userId,
            lemma: "delta",
            status: .learning,
            nextReviewDate: now.addingTimeInterval(2 * 60 * 60),
            stability: 1.0,
            reviewCount: 1,
            modelContext: context
        )
        seedState(
            userId: userId,
            lemma: "echo",
            status: .new,
            nextReviewDate: now.addingTimeInterval(60 * 60),
            stability: 8.0,
            reviewCount: 0,
            modelContext: context
        )
        seedState(
            userId: userId,
            lemma: "foxtrot",
            status: .learning,
            nextReviewDate: now.addingTimeInterval(2 * 60 * 60),
            stability: 0.5,
            reviewCount: 3,
            modelContext: context
        )
        try context.save()

        let manager = SessionManager(modelContext: context)
        manager.startFallbackPracticeSession()

        XCTAssertEqual(manager.queue.map(\.lemma), ["echo", "foxtrot", "delta"])
    }

    func testFallbackQueueLimitedToTen() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = UserProfile.resolveActiveProfile(modelContext: context).userId
        let now = Date()

        try setPremium(modelContext: context)

        for index in 0..<12 {
            let lemma = "lemma\(index)"
            seedLexeme(lemma, modelContext: context)
            seedState(
                userId: userId,
                lemma: lemma,
                status: .learning,
                nextReviewDate: now.addingTimeInterval(TimeInterval((index + 1) * 60)),
                stability: Double(index),
                reviewCount: 1,
                modelContext: context
            )
        }
        try context.save()

        let manager = SessionManager(modelContext: context)
        manager.startFallbackPracticeSession()

        XCTAssertEqual(manager.queue.count, 10)
    }

    func testFallbackAgainHardLoggedGoodEasyNotLogged() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = UserProfile.resolveActiveProfile(modelContext: context).userId
        let now = Date()

        try setPremium(modelContext: context)

        seedLexeme("practice", modelContext: context)
        seedState(
            userId: userId,
            lemma: "practice",
            status: .learning,
            nextReviewDate: now.addingTimeInterval(60 * 60),
            stability: 6.0,
            reviewCount: 2,
            modelContext: context
        )
        try context.save()

        let manager = SessionManager(modelContext: context)
        manager.startFallbackPracticeSession()

        manager.submitGrade(1)
        let firstFinished = await waitUntil { !manager.isSubmittingGrade }
        XCTAssertTrue(firstFinished)
        manager.submitGrade(2)
        let secondFinished = await waitUntil { !manager.isSubmittingGrade }
        XCTAssertTrue(secondFinished)
        manager.submitGrade(3)
        let thirdFinished = await waitUntil { !manager.isSubmittingGrade }
        XCTAssertTrue(thirdFinished)
        manager.submitGrade(4)
        let fourthFinished = await waitUntil { !manager.isSubmittingGrade }
        XCTAssertTrue(fourthFinished)

        let events = try fetchEvents(lemma: "practice", modelContext: context)
        XCTAssertEqual(events.map(\.reviewState), [
            ReviewEvent.sessionReviewState(for: 1),
            ReviewEvent.sessionReviewState(for: 2)
        ])
    }

    func testFallbackDoesNotMutateUserWordStateSchedule() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = UserProfile.resolveActiveProfile(modelContext: context).userId
        let now = Date()
        let nextReviewDate = now.addingTimeInterval(90 * 60)

        try setPremium(modelContext: context)

        seedLexeme("stable", modelContext: context)
        seedState(
            userId: userId,
            lemma: "stable",
            status: .learning,
            nextReviewDate: nextReviewDate,
            stability: 8.0,
            reviewCount: 3,
            modelContext: context
        )
        try context.save()

        let before = try XCTUnwrap(fetchState(userId: userId, lemma: "stable", modelContext: context))

        let manager = SessionManager(modelContext: context)
        manager.startFallbackPracticeSession()

        manager.submitGrade(1)
        let firstFinished = await waitUntil { !manager.isSubmittingGrade }
        XCTAssertTrue(firstFinished)
        manager.submitGrade(2)
        let secondFinished = await waitUntil { !manager.isSubmittingGrade }
        XCTAssertTrue(secondFinished)
        manager.submitGrade(3)
        let thirdFinished = await waitUntil { !manager.isSubmittingGrade }
        XCTAssertTrue(thirdFinished)
        manager.submitGrade(4)
        let fourthFinished = await waitUntil { !manager.isSubmittingGrade }
        XCTAssertTrue(fourthFinished)

        let after = try XCTUnwrap(fetchState(userId: userId, lemma: "stable", modelContext: context))
        XCTAssertEqual(after.reviewCount, before.reviewCount)
        XCTAssertEqual(after.stability, before.stability, accuracy: 0.0001)
        XCTAssertEqual(after.difficulty, before.difficulty, accuracy: 0.0001)
        XCTAssertEqual(after.nextReviewDate, before.nextReviewDate)
        XCTAssertEqual(after.lastReviewDate, before.lastReviewDate)
    }

    func testDueModeStillPerformsExplicitUpdates() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = UserProfile.resolveActiveProfile(modelContext: context).userId
        let now = Date()

        seedLexeme("dueword", modelContext: context)
        seedState(
            userId: userId,
            lemma: "dueword",
            status: .learning,
            nextReviewDate: now.addingTimeInterval(-60),
            stability: 5.0,
            reviewCount: 2,
            modelContext: context
        )
        try context.save()

        let before = try XCTUnwrap(fetchState(userId: userId, lemma: "dueword", modelContext: context))
        let beforeReviewCount = before.reviewCount
        let manager = SessionManager(modelContext: context)
        manager.startSession(mode: .dueOnly)
        XCTAssertEqual(manager.queue.count, 1)

        manager.submitGrade(4)
        let finished = await waitUntil { !manager.isSubmittingGrade && manager.queue.isEmpty }
        XCTAssertTrue(finished)

        let after = try XCTUnwrap(fetchState(userId: userId, lemma: "dueword", modelContext: context))
        XCTAssertEqual(after.reviewCount, beforeReviewCount + 1)
        XCTAssertNotNil(after.lastReviewDate)
        XCTAssertTrue((after.nextReviewDate ?? .distantPast) > now)

        let events = try fetchEvents(lemma: "dueword", modelContext: context)
        XCTAssertEqual(events.last?.reviewState, ReviewEvent.reviewState(for: 4))
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV6.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: LexicalMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func seedLexeme(_ lemma: String, modelContext: ModelContext) {
        modelContext.insert(
            LexemeDefinition(
                lemma: lemma,
                rank: 2500,
                basicMeaning: "Definition for \(lemma)",
                sampleSentence: "Sentence for \(lemma)."
            )
        )
    }

    private func seedState(
        userId: String,
        lemma: String,
        status: UserWordStatus,
        nextReviewDate: Date,
        stability: Double,
        reviewCount: Int,
        modelContext: ModelContext
    ) {
        let state = UserWordState(
            userId: userId,
            lemma: lemma,
            status: status,
            stability: stability,
            difficulty: 3.0,
            retrievability: 0.8,
            nextReviewDate: nextReviewDate,
            lastReviewDate: nextReviewDate.addingTimeInterval(-86_400),
            reviewCount: reviewCount
        )
        modelContext.insert(state)
    }

    private func fetchEvents(lemma: String, modelContext: ModelContext) throws -> [ReviewEvent] {
        let descriptor = FetchDescriptor<ReviewEvent>(
            predicate: #Predicate { event in
                event.lemma == lemma
            },
            sortBy: [SortDescriptor(\ReviewEvent.reviewDate, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchState(
        userId: String,
        lemma: String,
        modelContext: ModelContext
    ) -> UserWordState? {
        let key = UserWordState.makeKey(userId: userId, lemma: lemma)
        let descriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { state in
                state.userLemmaKey == key
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func setPremium(modelContext: ModelContext) throws {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        profile.applySubscriptionTier(.premium, source: .localCache)
        try modelContext.save()
    }

    private func waitUntil(
        timeout: TimeInterval = 2.0,
        pollNanoseconds: UInt64 = 20_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }
}
