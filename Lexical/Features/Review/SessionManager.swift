import Foundation
import SwiftData
import SwiftUI
import LexicalCore

/// Manages the active review session queue and Brain Boost logic.
@MainActor
class SessionManager: ObservableObject {
    @Published var queue: [ReviewCard] = []
    @Published var currentIndex: Int = 0
    @Published var isSessionComplete: Bool = false

    private let modelContext: ModelContext
    private let fsrsEngine: FSRSV4Engine

    // Track streaks for Brain Boost (consecutive successes in this session).
    @Published var sessionStreaks: [String: Int] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.fsrsEngine = FSRSV4Engine()
    }

    /// Start a new session with due cards.
    func startSession() {
        do {
            let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
            let dueCards = try dueCardsFromUserState(userId: activeProfile.userId)

            if dueCards.isEmpty {
                let allStates = try modelContext.fetch(FetchDescriptor<UserWordState>())
                    .filter { $0.userId == activeProfile.userId && $0.status != .ignored }
                    .sorted { ($0.nextReviewDate ?? Date.distantFuture) < ($1.nextReviewDate ?? Date.distantFuture) }

                let lexemeByLemma = try fetchLexemeMap()
                self.queue = allStates.prefix(20).map { state in
                    makeCard(from: state, lexemeByLemma: lexemeByLemma)
                }
            } else {
                self.queue = dueCards
            }

            self.currentIndex = 0
            self.isSessionComplete = queue.isEmpty
            print("🧠 Session started with \(queue.count) items")
        } catch {
            print("SessionManager: failed to fetch session items: \(error)")
            self.queue = []
            self.currentIndex = 0
            self.isSessionComplete = true
        }
    }

    /// Current active card.
    var currentCard: ReviewCard? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    func submitGrade(_ grade: Int) {
        guard var card = currentCard else { return }
        let cardKey = card.lemma

        Task { @MainActor in
            let newState = await fsrsEngine.nextState(
                currentStability: card.stability,
                currentDifficulty: card.difficulty,
                recalled: grade >= 3,
                grade: grade,
                daysElapsed: max(0, Date().timeIntervalSince(card.lastReviewDate ?? card.createdAt) / 86400)
            )

            let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
            let projectedIntervalDays = await fsrsEngine.nextInterval(
                stability: max(newState.stability, 0.1),
                requestRetention: 0.9
            )

            let event = ReviewEvent(
                userId: activeProfile.userId,
                lemma: card.lemma,
                grade: grade,
                durationMs: 0,
                scheduledDays: projectedIntervalDays,
                reviewState: ReviewEvent.reviewState(for: grade)
            )
            modelContext.insert(event)
            print("📝 Logged review for '\(card.lemma)': Grade \(grade)")

            if grade < 3 {
                // FAIL/HARD (1 or 2)
                print("🧠 Brain Boost: Re-queueing '\(card.lemma)' (Grade \(grade))")
                sessionStreaks[cardKey] = 0
                reinsertCurrentCard(offset: 3)
            } else if grade == 3 {
                // GOOD (3)
                let currentStreak = (sessionStreaks[cardKey] ?? 0) + 1
                sessionStreaks[cardKey] = currentStreak

                if currentStreak < 2 {
                    print("🧠 Good! Streak \(currentStreak)/2. Re-queueing '\(card.lemma)'")
                    reinsertCurrentCard(offset: 5)
                } else {
                    print("✅ Graduated '\(card.lemma)'")
                    card = await updateCardState(card, newState: newState)
                    upsertUserWordState(for: card, userId: activeProfile.userId, grade: grade)
                    replaceCurrentCardAndAdvance(with: card)
                }
            } else {
                // EASY (4)
                print("✅ Graduated '\(card.lemma)' (Easy)")
                card = await updateCardState(card, newState: newState)
                upsertUserWordState(for: card, userId: activeProfile.userId, grade: grade)
                replaceCurrentCardAndAdvance(with: card)
            }

            do {
                try modelContext.save()
            } catch {
                print("SessionManager: failed to save review updates: \(error)")
            }
        }
    }

    /// Update the card with final FSRS state/date after graduation.
    private func updateCardState(_ card: ReviewCard, newState: FSRSV4Engine.FSRSState) async -> ReviewCard {
        var updated = card
        updated.stability = max(newState.stability, 0.1)
        updated.difficulty = newState.difficulty
        updated.retrievability = newState.retrievability
        updated.lastReviewDate = Date()
        updated.reviewCount += 1

        let intervalDays = await fsrsEngine.nextInterval(
            stability: updated.stability,
            requestRetention: 0.9
        )
        updated.nextReviewDate = Date().addingTimeInterval(intervalDays * 86400)
        updated.status = statusFor(updated)
        return updated
    }

    /// Move the current card to a later position in the session (Brain Boost).
    private func reinsertCurrentCard(offset: Int) {
        guard currentIndex < queue.count else { return }
        let card = queue[currentIndex]

        queue.remove(at: currentIndex)
        let newIndex = min(currentIndex + offset, queue.count)
        queue.insert(card, at: newIndex)
    }

    /// Replace current card snapshot and advance the queue.
    private func replaceCurrentCardAndAdvance(with card: ReviewCard) {
        guard currentIndex < queue.count else { return }
        queue[currentIndex] = card
        advanceQueue()
    }

    /// Advance to the next card in the queue.
    private func advanceQueue() {
        if currentIndex < queue.count {
            queue.remove(at: currentIndex)
        }

        if queue.isEmpty {
            isSessionComplete = true
        }

        currentIndex = 0
    }

    private func dueCardsFromUserState(userId: String) throws -> [ReviewCard] {
        let now = Date()
        let allStates = try modelContext.fetch(FetchDescriptor<UserWordState>())
        let dueStates = allStates
            .filter { state in
                state.userId == userId &&
                state.status != .ignored &&
                (state.nextReviewDate ?? now) <= now
            }
            .sorted { ($0.nextReviewDate ?? Date.distantPast) < ($1.nextReviewDate ?? Date.distantPast) }

        guard !dueStates.isEmpty else { return [] }

        let lexemeByLemma = try fetchLexemeMap()
        return dueStates.map { state in
            makeCard(from: state, lexemeByLemma: lexemeByLemma)
        }
    }

    private func fetchLexemeMap() throws -> [String: LexemeDefinition] {
        let lexemes = try modelContext.fetch(FetchDescriptor<LexemeDefinition>())
        var lexemeByLemma: [String: LexemeDefinition] = [:]
        lexemeByLemma.reserveCapacity(lexemes.count)
        for lexeme in lexemes {
            lexemeByLemma[lexeme.lemma] = lexeme
        }
        return lexemeByLemma
    }

    private func makeCard(
        from state: UserWordState,
        lexemeByLemma: [String: LexemeDefinition]
    ) -> ReviewCard {
        let lexeme = lexemeByLemma[state.lemma]
        return ReviewCard(
            lemma: state.lemma,
            originalWord: state.lemma,
            contextSentence: lexeme?.sampleSentence ?? "Use '\(state.lemma)' in a sentence.",
            definition: lexeme?.basicMeaning,
            stability: state.stability,
            difficulty: state.difficulty,
            retrievability: state.retrievability,
            nextReviewDate: state.nextReviewDate,
            lastReviewDate: state.lastReviewDate,
            reviewCount: state.reviewCount,
            createdAt: state.createdAt,
            status: state.status
        )
    }

    private func upsertUserWordState(for card: ReviewCard, userId: String, grade: Int) {
        let key = UserWordState.makeKey(userId: userId, lemma: card.lemma)
        let descriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )

        let state: UserWordState
        if let existing = try? modelContext.fetch(descriptor).first {
            state = existing
        } else {
            state = UserWordState(userId: userId, lemma: card.lemma)
            modelContext.insert(state)
        }

        state.stability = card.stability
        state.difficulty = card.difficulty
        state.retrievability = card.retrievability
        state.nextReviewDate = card.nextReviewDate
        state.lastReviewDate = card.lastReviewDate
        state.reviewCount = card.reviewCount
        if grade == 1 {
            state.lapseCount += 1
        }
        state.status = statusFor(card)
        state.touch()
    }

    private func statusFor(_ card: ReviewCard) -> UserWordStatus {
        if card.stability >= 90 {
            return .known
        }
        if card.reviewCount > 0 {
            return .learning
        }
        return .new
    }
}
