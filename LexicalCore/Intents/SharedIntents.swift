import AppIntents
import SwiftData
import Foundation

// MARK: - App Entity Conformance

public struct VocabularyItemEntity: AppEntity {
    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Vocabulary Item")
    public static var defaultQuery = VocabularyItemQuery()

    public var id: String
    public var lemma: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(lemma)")
    }

    public init(id: String, lemma: String) {
        self.id = id
        self.lemma = lemma
    }
}

public struct VocabularyItemQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [VocabularyItemEntity] {
        []
    }

    public func suggestedEntities() async throws -> [VocabularyItemEntity] {
        []
    }
}

// MARK: - Intents

public struct StartReviewIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Review Session"
    public static var description = IntentDescription("Opens the app and starts a review session.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        .result()
    }
}

public struct GetDueCountIntent: AppIntent {
    public static var title: LocalizedStringResource = "Check Due Reviews"
    public static var description = IntentDescription("Checks how many cards are due for review.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let modelContext = ModelContext(Persistence.sharedModelContainer)
        let activeUser = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let now = Date()

        let count: Int
        do {
            let userStates = try modelContext.fetch(FetchDescriptor<UserWordState>())
            count = userStates.filter { state in
                state.userId == activeUser.userId &&
                state.status != .ignored &&
                (state.nextReviewDate ?? now) <= now
            }.count
        } catch {
            count = 0
        }

        return .result(
            value: count,
            dialog: IntentDialog("You have \(count) cards due for review.")
        )
    }
}

public struct GradeCardIntent: AppIntent {
    public static var title: LocalizedStringResource = "Grade Card"
    public static var description = IntentDescription("Grades a specific card from a widget.")

    @Parameter(title: "Lemma")
    public var lemma: String?

    @Parameter(title: "Grade")
    public var grade: Int?

    public init() {}

    public init(lemma: String, grade: Int) {
        self.lemma = lemma
        self.grade = grade
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        guard let lemma = lemma?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !lemma.isEmpty,
              let grade,
              (1...4).contains(grade) else {
            return .result()
        }

        let modelContext = ModelContext(Persistence.sharedModelContainer)

        do {
            let activeUser = UserProfile.resolveActiveProfile(modelContext: modelContext)
            let key = UserWordState.makeKey(userId: activeUser.userId, lemma: lemma)
            let stateDescriptor = FetchDescriptor<UserWordState>(
                predicate: #Predicate { $0.userLemmaKey == key }
            )

            let state = try modelContext.fetch(stateDescriptor).first ?? {
                let created = UserWordState(
                    userId: activeUser.userId,
                    lemma: lemma,
                    status: .learning,
                    nextReviewDate: Date()
                )
                modelContext.insert(created)
                return created
            }()

            let fsrs = FSRSV4Engine()
            let lastReview = state.lastReviewDate ?? state.createdAt
            let elapsedSeconds = Date().timeIntervalSince(lastReview)
            let daysElapsed = max(0, elapsedSeconds / 86_400.0)

            let newState = await fsrs.nextState(
                currentStability: max(state.stability, 0.1),
                currentDifficulty: max(state.difficulty, 0.3),
                recalled: grade > 1,
                grade: grade,
                daysElapsed: daysElapsed
            )

            let interval = await fsrs.nextInterval(stability: max(newState.stability, 0.1))

            state.stability = max(newState.stability, 0.1)
            state.difficulty = newState.difficulty
            state.retrievability = newState.retrievability
            state.lastReviewDate = Date()
            state.nextReviewDate = Date().addingTimeInterval(interval * 86_400)
            state.reviewCount += 1
            if grade == 1 {
                state.lapseCount += 1
            }
            state.status = statusFor(stability: state.stability, reviewCount: state.reviewCount)
            state.touch()

            let event = ReviewEvent(
                userId: activeUser.userId,
                lemma: lemma,
                grade: grade,
                durationMs: 0,
                scheduledDays: interval,
                reviewState: ReviewEvent.reviewState(for: grade)
            )
            modelContext.insert(event)

            try modelContext.save()
        } catch {
            print("GradeCardIntent error: \(error)")
        }

        return .result()
    }

    private func statusFor(stability: Double, reviewCount: Int) -> UserWordStatus {
        if stability >= 90 {
            return .known
        }
        if reviewCount > 0 {
            return .learning
        }
        return .new
    }
}
