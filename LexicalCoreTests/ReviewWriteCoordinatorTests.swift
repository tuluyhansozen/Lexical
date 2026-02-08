import Foundation
import LexicalCore
import SwiftData
import XCTest

@MainActor
final class ReviewWriteCoordinatorTests: XCTestCase {
    func testExplicitSubmissionPersistsReviewEvent() throws {
        let container = try makeInMemoryContainer()
        let coordinator = ReviewWriteCoordinatorContract(
            modelContext: container.mainContext,
            implicitThrottle: 2 * 60 * 60
        )
        let reviewDate = Date(timeIntervalSince1970: 1_705_300_000)

        let event = try coordinator.submitExplicitReview(
            userId: "review.user.explicit",
            lemma: "resilient",
            grade: 4,
            reviewDate: reviewDate
        )

        let persisted = try coordinator.fetchEvents(userId: "review.user.explicit", lemma: "resilient")
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(event.reviewState, "explicit")
        XCTAssertEqual(event.grade, 4)
        XCTAssertEqual(persisted.first?.lemma, "resilient")
    }

    func testImplicitExposureIsThrottledWithinWindow() throws {
        let container = try makeInMemoryContainer()
        let coordinator = ReviewWriteCoordinatorContract(
            modelContext: container.mainContext,
            implicitThrottle: 2 * 60 * 60
        )
        let t0 = Date(timeIntervalSince1970: 1_705_300_000)

        let first = try coordinator.submitImplicitExposure(
            userId: "review.user.implicit",
            lemma: "contextual",
            reviewDate: t0
        )
        let second = try coordinator.submitImplicitExposure(
            userId: "review.user.implicit",
            lemma: "contextual",
            reviewDate: t0.addingTimeInterval(30 * 60)
        )
        let third = try coordinator.submitImplicitExposure(
            userId: "review.user.implicit",
            lemma: "contextual",
            reviewDate: t0.addingTimeInterval((2 * 60 * 60) + 10)
        )

        XCTAssertNotNil(first)
        XCTAssertNil(second)
        XCTAssertNotNil(third)

        let events = try coordinator.fetchEvents(userId: "review.user.implicit", lemma: "contextual")
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.allSatisfy { $0.reviewState == "implicit_exposure" })
        XCTAssertTrue(events.allSatisfy { $0.scheduledDays <= 0.25 })
    }

    func testImplicitThrottleIsScopedPerLemma() throws {
        let container = try makeInMemoryContainer()
        let coordinator = ReviewWriteCoordinatorContract(
            modelContext: container.mainContext,
            implicitThrottle: 2 * 60 * 60
        )
        let timestamp = Date(timeIntervalSince1970: 1_705_300_000)

        let firstLemma = try coordinator.submitImplicitExposure(
            userId: "review.user.multilemma",
            lemma: "signal",
            reviewDate: timestamp
        )
        let secondLemma = try coordinator.submitImplicitExposure(
            userId: "review.user.multilemma",
            lemma: "throttle",
            reviewDate: timestamp.addingTimeInterval(60)
        )

        XCTAssertNotNil(firstLemma)
        XCTAssertNotNil(secondLemma)

        let allEvents = try coordinator.fetchEvents(userId: "review.user.multilemma", lemma: nil)
        XCTAssertEqual(allEvents.count, 2)
        XCTAssertEqual(Set(allEvents.map(\.lemma)), ["signal", "throttle"])
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV3.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@MainActor
private final class ReviewWriteCoordinatorContract {
    private let modelContext: ModelContext
    private let implicitThrottle: TimeInterval
    private var lastImplicitExposureByLemma: [String: Date] = [:]

    init(modelContext: ModelContext, implicitThrottle: TimeInterval) {
        self.modelContext = modelContext
        self.implicitThrottle = implicitThrottle
    }

    @discardableResult
    func submitExplicitReview(
        userId: String,
        lemma: String,
        grade: Int,
        reviewDate: Date
    ) throws -> ReviewEvent {
        let event = ReviewEvent(
            userId: userId,
            lemma: lemma,
            grade: grade,
            reviewDate: reviewDate,
            durationMs: 900,
            scheduledDays: 1.0,
            reviewState: "explicit",
            deviceId: "test.device"
        )
        modelContext.insert(event)
        try modelContext.save()
        return event
    }

    @discardableResult
    func submitImplicitExposure(
        userId: String,
        lemma: String,
        reviewDate: Date
    ) throws -> ReviewEvent? {
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let throttleKey = UserWordState.makeKey(userId: userId, lemma: normalizedLemma)

        if let lastWrite = lastImplicitExposureByLemma[throttleKey],
           reviewDate.timeIntervalSince(lastWrite) < implicitThrottle {
            return nil
        }

        lastImplicitExposureByLemma[throttleKey] = reviewDate
        let event = ReviewEvent(
            userId: userId,
            lemma: normalizedLemma,
            grade: 3,
            reviewDate: reviewDate,
            durationMs: 250,
            scheduledDays: 0.2,
            reviewState: "implicit_exposure",
            deviceId: "test.device"
        )
        modelContext.insert(event)
        try modelContext.save()
        return event
    }

    func fetchEvents(
        userId: String,
        lemma: String?
    ) throws -> [ReviewEvent] {
        let allEvents = try modelContext.fetch(FetchDescriptor<ReviewEvent>())
        return allEvents
            .filter { event in
                guard event.userId == userId else { return false }
                if let lemma {
                    return event.lemma == lemma.lowercased()
                }
                return true
            }
            .sorted { $0.reviewDate < $1.reviewDate }
    }
}
