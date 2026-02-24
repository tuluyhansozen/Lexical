import Foundation
import SwiftData
import SwiftUI
import LexicalCore

enum ReviewSessionMode: Equatable {
    case dueOnly
    case fallbackPractice
}

/// Manages the active review session queue and Brain Boost logic.
@MainActor
class SessionManager: ObservableObject {
    private static let fallbackPracticeLimit = 10

    @Published var queue: [ReviewCard] = []
    @Published var currentIndex: Int = 0
    @Published var isSessionComplete: Bool = false
    @Published var hadDueCardsAtSessionStart: Bool = false
    @Published var initialQueueCount: Int = 0
    @Published var sessionMode: ReviewSessionMode = .dueOnly
    @Published var canStartFallbackPractice: Bool = false
    @Published var isPremiumUser: Bool = false
    @Published private(set) var isSubmittingGrade: Bool = false

    private let modelContext: ModelContext
    private let fsrsEngine: FSRSV4Engine
    private let reviewCoordinator: ReviewWriteCoordinator
    private let featureGateService: FeatureGateService
    private let fsrsPersonalizationService: FSRSPersonalizationService
    private var requestRetentionTarget: Double = 0.9
    private var sessionFSRSWeights: [Double]?

    // Track streaks for Brain Boost (consecutive successes in this session).
    @Published var sessionStreaks: [String: Int] = [:]

    var completedCount: Int {
        max(0, initialQueueCount - queue.count)
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.fsrsEngine = FSRSV4Engine()
        self.featureGateService = FeatureGateService()
        self.fsrsPersonalizationService = FSRSPersonalizationService()
        self.reviewCoordinator = ReviewWriteCoordinator()
    }

    /// Start a new session in due-only or fallback-practice mode.
    func startSession(mode: ReviewSessionMode = .dueOnly) {
        do {
            let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
            let activeTier = featureGateService.activeTier(modelContext: modelContext)
            let isPremiumTier = activeTier == .premium
            isPremiumUser = isPremiumTier
            requestRetentionTarget = featureGateService.fsrsRequestRetention(for: activeProfile)
            sessionFSRSWeights = try? fsrsPersonalizationService.personalizedWeights(
                for: activeProfile,
                modelContext: modelContext
            )
            let selectedCards: [ReviewCard]
            switch mode {
            case .dueOnly:
                let dueCards = try dueCardsFromUserState(userId: activeProfile.userId)
                selectedCards = dueCards
                hadDueCardsAtSessionStart = !dueCards.isEmpty
                if dueCards.isEmpty, isPremiumTier {
                    canStartFallbackPractice = !(try fallbackPracticeCardsFromUserState(
                        userId: activeProfile.userId,
                        limit: 1
                    )).isEmpty
                } else {
                    canStartFallbackPractice = false
                }
            case .fallbackPractice:
                if isPremiumTier {
                    selectedCards = try fallbackPracticeCardsFromUserState(
                        userId: activeProfile.userId,
                        limit: Self.fallbackPracticeLimit
                    )
                } else {
                    selectedCards = []
                }
                hadDueCardsAtSessionStart = false
                canStartFallbackPractice = false
            }

            sessionMode = mode
            queue = selectedCards
            initialQueueCount = selectedCards.count
            sessionStreaks = [:]

            self.currentIndex = 0
            self.isSessionComplete = queue.isEmpty
            self.isSubmittingGrade = false
            print("🧠 Session started (\(mode)) with \(queue.count) items")
        } catch {
            print("SessionManager: failed to fetch session items: \(error)")
            self.queue = []
            self.currentIndex = 0
            self.isSessionComplete = true
            self.hadDueCardsAtSessionStart = false
            self.initialQueueCount = 0
            self.sessionMode = mode
            self.canStartFallbackPractice = false
            self.isPremiumUser = false
            self.sessionStreaks = [:]
            self.isSubmittingGrade = false
        }
    }

    func startFallbackPracticeSession() {
        guard featureGateService.activeTier(modelContext: modelContext) == .premium else {
            return
        }
        startSession(mode: .fallbackPractice)
    }

    /// Current active card.
    var currentCard: ReviewCard? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    func removeCurrentCardFromDeck() {
        guard let current = currentCard else { return }

        let normalizedLemma = current.lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedLemma.isEmpty else { return }

        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        activeProfile.markIgnored(normalizedLemma)

        let key = UserWordState.makeKey(userId: activeProfile.userId, lemma: normalizedLemma)
        let descriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        let state = (try? modelContext.fetch(descriptor).first) ?? {
            let created = UserWordState(
                userId: activeProfile.userId,
                lemma: normalizedLemma,
                status: .ignored
            )
            modelContext.insert(created)
            return created
        }()

        state.status = .ignored
        state.touch()

        do {
            try modelContext.save()
        } catch {
            print("SessionManager: failed to remove '\(normalizedLemma)' from deck: \(error)")
        }

        Task { @MainActor in
            if currentIndex < queue.count {
                queue.remove(at: currentIndex)
            }
            sessionStreaks.removeValue(forKey: normalizedLemma)
            currentIndex = 0
            isSessionComplete = queue.isEmpty
        }
    }

    func submitGrade(_ grade: Int) {
        guard !isSubmittingGrade else { return }
        guard let card = currentCard else { return }
        isSubmittingGrade = true
        let cardKey = card.lemma

        Task { @MainActor in
            defer { isSubmittingGrade = false }
            if sessionMode == .fallbackPractice {
                await submitFallbackPracticeGrade(
                    grade,
                    card: card,
                    cardKey: cardKey
                )
                return
            }

            if grade < 3 {
                let projectedIntervalDays = await projectedIntervalDays(for: card, grade: grade)
                do {
                    try reviewCoordinator.recordSessionAttempt(
                        grade: grade,
                        lemma: card.lemma,
                        durationMs: 0,
                        scheduledDays: projectedIntervalDays,
                        modelContext: modelContext
                    )
                    print("📝 Logged review for '\(card.lemma)': Grade \(grade)")
                } catch {
                    print("SessionManager: failed to log Brain Boost attempt: \(error)")
                }

                // FAIL/HARD (1 or 2)
                print("🧠 Brain Boost: Re-queueing '\(card.lemma)' (Grade \(grade))")
                sessionStreaks[cardKey] = 0
                reinsertCurrentCard(offset: 3)
            } else if grade == 3 {
                // GOOD (3)
                let currentStreak = (sessionStreaks[cardKey] ?? 0) + 1
                sessionStreaks[cardKey] = currentStreak

                if currentStreak < 2 {
                    let projectedIntervalDays = await projectedIntervalDays(for: card, grade: grade)
                    do {
                        try reviewCoordinator.recordSessionAttempt(
                            grade: grade,
                            lemma: card.lemma,
                            durationMs: 0,
                            scheduledDays: projectedIntervalDays,
                            modelContext: modelContext
                        )
                        print("📝 Logged review for '\(card.lemma)': Grade \(grade)")
                    } catch {
                        print("SessionManager: failed to log Brain Boost attempt: \(error)")
                    }

                    print("🧠 Good! Streak \(currentStreak)/2. Re-queueing '\(card.lemma)'")
                    reinsertCurrentCard(offset: 5)
                } else {
                    print("✅ Graduated '\(card.lemma)'")
                    do {
                        _ = try await reviewCoordinator.recordExplicitReview(
                            grade: grade,
                            lemma: card.lemma,
                            durationMs: 0,
                            modelContext: modelContext
                        )
                        advanceQueue()
                    } catch {
                        print("SessionManager: coordinator explicit write failed: \(error)")
                    }
                }
            } else {
                // EASY (4)
                print("✅ Graduated '\(card.lemma)' (Easy)")
                do {
                    _ = try await reviewCoordinator.recordExplicitReview(
                        grade: grade,
                        lemma: card.lemma,
                        durationMs: 0,
                        modelContext: modelContext
                    )
                    advanceQueue()
                } catch {
                    print("SessionManager: coordinator explicit write failed: \(error)")
                }
            }
        }
    }

    private func sortedFallbackStates(
        _ states: [UserWordState]
    ) -> [UserWordState] {
        states.sorted { lhs, rhs in
            let lhsDate = lhs.nextReviewDate ?? Date.distantFuture
            let rhsDate = rhs.nextReviewDate ?? Date.distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            if lhs.stability != rhs.stability { return lhs.stability < rhs.stability }
            return lhs.lemma < rhs.lemma
        }
    }

    private func fallbackPracticeCardsFromUserState(
        userId: String,
        limit: Int = 10
    ) throws -> [ReviewCard] {
        guard limit > 0 else { return [] }
        let now = Date()
        let allStates = try modelContext.fetch(FetchDescriptor<UserWordState>())
        let primaryStates = allStates.filter { state in
            state.userId == userId &&
            state.status != .ignored &&
            (state.status == .learning || state.status == .new) &&
            (state.nextReviewDate ?? Date.distantFuture) > now
        }

        let chosenStates: [UserWordState]
        if primaryStates.isEmpty {
            chosenStates = knownBackupCardsFromUserState(
                allStates: allStates,
                userId: userId
            )
        } else {
            chosenStates = sortedFallbackStates(primaryStates)
        }

        guard !chosenStates.isEmpty else { return [] }

        let lexemeByLemma = try fetchLexemeMap()
        return chosenStates.prefix(limit).map { state in
            makeCard(from: state, lexemeByLemma: lexemeByLemma)
        }
    }

    private func knownBackupCardsFromUserState(
        allStates: [UserWordState],
        userId: String
    ) -> [UserWordState] {
        let now = Date()
        let knownStates = allStates.filter { state in
            state.userId == userId &&
            state.status == .known &&
            (state.nextReviewDate ?? Date.distantFuture) > now
        }
        return sortedFallbackStates(knownStates)
    }

    private func submitFallbackPracticeGrade(
        _ grade: Int,
        card: ReviewCard,
        cardKey: String
    ) async {
        if grade < 3 {
            let projectedIntervalDays = await projectedIntervalDays(for: card, grade: grade)
            do {
                try reviewCoordinator.recordSessionAttempt(
                    grade: grade,
                    lemma: card.lemma,
                    durationMs: 0,
                    scheduledDays: projectedIntervalDays,
                    modelContext: modelContext
                )
                print("📝 Logged fallback practice review for '\(card.lemma)': Grade \(grade)")
            } catch {
                print("SessionManager: failed to log fallback practice attempt: \(error)")
            }

            sessionStreaks[cardKey] = 0
            reinsertCurrentCard(offset: 3)
            return
        }

        if grade == 3 {
            let currentStreak = (sessionStreaks[cardKey] ?? 0) + 1
            sessionStreaks[cardKey] = currentStreak

            if currentStreak < 2 {
                reinsertCurrentCard(offset: 5)
                return
            }

            advanceQueue()
            return
        }

        advanceQueue()
    }

    /// Move the current card to a later position in the session (Brain Boost).
    private func reinsertCurrentCard(offset: Int) {
        guard currentIndex < queue.count else { return }
        let card = queue[currentIndex]

        queue.remove(at: currentIndex)
        let newIndex = min(currentIndex + offset, queue.count)
        queue.insert(card, at: newIndex)
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

    private func projectedIntervalDays(for card: ReviewCard, grade: Int) async -> Double {
        let transition = await fsrsEngine.nextState(
            currentStability: card.stability,
            currentDifficulty: card.difficulty,
            recalled: grade >= 3,
            grade: grade,
            daysElapsed: max(0, Date().timeIntervalSince(card.lastReviewDate ?? card.createdAt) / 86400),
            weights: sessionFSRSWeights
        )
        return await fsrsEngine.nextInterval(
            stability: max(transition.stability, 0.1),
            requestRetention: requestRetentionTarget
        )
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

}
