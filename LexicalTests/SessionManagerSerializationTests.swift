import XCTest
import SwiftData
import LexicalCore
@testable import Lexical

@MainActor
final class SessionManagerSerializationTests: XCTestCase {
    func testSubmitGradeIgnoresSecondTapForSessionAttemptPath() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let manager = SessionManager(modelContext: context)
        manager.queue = [makeCard(lemma: "ephemeral")]

        manager.submitGrade(2)
        manager.submitGrade(2)

        let finished = await waitUntil(timeout: 1.5) {
            !manager.isSubmittingGrade
        }
        XCTAssertTrue(finished)

        let events = try fetchEvents(lemma: "ephemeral", modelContext: context)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.reviewState, ReviewEvent.sessionReviewState(for: 2))
        XCTAssertEqual(manager.queue.count, 1)
    }

    func testSubmitGradeIgnoresSecondTapForExplicitPath() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let manager = SessionManager(modelContext: context)
        manager.queue = [makeCard(lemma: "resolute")]

        manager.submitGrade(4)
        manager.submitGrade(4)

        let finished = await waitUntil(timeout: 2.0) {
            !manager.isSubmittingGrade && manager.queue.isEmpty
        }
        XCTAssertTrue(finished)

        let events = try fetchEvents(lemma: "resolute", modelContext: context)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.reviewState, ReviewEvent.reviewState(for: 4))
        XCTAssertTrue(manager.isSessionComplete)
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

    private func makeCard(lemma: String) -> ReviewCard {
        ReviewCard(
            lemma: lemma,
            originalWord: lemma,
            contextSentence: "Example sentence for \(lemma).",
            definition: "Definition for \(lemma)",
            stability: 10,
            difficulty: 5,
            retrievability: 0.6,
            nextReviewDate: Date().addingTimeInterval(-60),
            lastReviewDate: Date().addingTimeInterval(-86_400),
            reviewCount: 1,
            createdAt: Date().addingTimeInterval(-86_400 * 3),
            status: .learning
        )
    }

    private func fetchEvents(lemma: String, modelContext: ModelContext) throws -> [ReviewEvent] {
        let normalizedLemma = lemma.lowercased()
        let descriptor = FetchDescriptor<ReviewEvent>(
            predicate: #Predicate { event in
                event.lemma == normalizedLemma
            },
            sortBy: [SortDescriptor(\ReviewEvent.reviewDate, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func waitUntil(
        timeout: TimeInterval,
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
