import Foundation
import SwiftData
import LexicalCore

enum E2ETestLaunchConfigurator {
    static let baseFlag = "--lexical-ui-tests"
    static let regularUsageScenarioFlag = "--lexical-e2e-scenario-regular-2words-day28-articles4"

    static var shouldSkipBootstrapTasks: Bool {
        ProcessInfo.processInfo.arguments.contains(baseFlag)
            || ProcessInfo.processInfo.arguments.contains("--lexical-e2e-no-bootstrap")
    }

    static func configureIfNeeded() {
        let arguments = Set(ProcessInfo.processInfo.arguments)
        guard arguments.contains(baseFlag) else { return }

        if arguments.contains("--lexical-e2e-reset-state") {
            resetUserDefaults()
            resetPersistentState()
        }

        if arguments.contains("--lexical-e2e-show-onboarding") {
            setOnboardingCompleted(false)
        }

        if arguments.contains("--lexical-e2e-complete-onboarding") {
            setOnboardingCompleted(true)
        }

        if arguments.contains(regularUsageScenarioFlag) {
            applyRegularUsageScenario()
        } else if arguments.contains("--lexical-e2e-free-limit") {
            applyReadingState(tier: .free, generatedCountInWindow: 1)
        } else if arguments.contains("--lexical-e2e-premium") {
            applyReadingState(tier: .premium, generatedCountInWindow: 0)
        }

        if arguments.contains("--lexical-e2e-pending-prompt") {
            UserDefaults.standard.set("spec", forKey: "lexical.pending_prompt_lemma")
            UserDefaults.standard.set("to inspect carefully", forKey: "lexical.pending_prompt_definition")
        }
    }

    private static func resetUserDefaults() {
        let keys = [
            OnboardingStorageKeys.completed,
            OnboardingStorageKeys.currentStep,
            OnboardingStorageKeys.notificationPrompted,
            OnboardingStorageKeys.articleStylePreference,
            OnboardingStorageKeys.calibrationRank,
            OnboardingStorageKeys.calibrationConfidence,
            "userName",
            "lexical.pending_prompt_lemma",
            "lexical.pending_prompt_definition",
            UserProfile.activeUserDefaultsKey
        ]

        let stores = [
            UserDefaults.standard,
            UserDefaults(suiteName: Persistence.appGroupIdentifier)
        ].compactMap { $0 }

        for store in stores {
            for key in keys {
                store.removeObject(forKey: key)
            }
        }
    }

    private static func setOnboardingCompleted(_ completed: Bool) {
        UserDefaults.standard.set(completed, forKey: OnboardingStorageKeys.completed)
        UserDefaults.standard.set(0, forKey: OnboardingStorageKeys.currentStep)
    }

    private static func resetPersistentState() {
        let context = ModelContext(Persistence.sharedModelContainer)

        deleteAll(GeneratedContent.self, in: context)
        deleteAll(UsageLedger.self, in: context)
        deleteAll(UserWordState.self, in: context)
        deleteAll(UserProfile.self, in: context)
        deleteAll(InterestProfile.self, in: context)
        deleteAll(ReviewEvent.self, in: context)
        deleteAll(ReviewLog.self, in: context)
        deleteAll(DiscoveredLexeme.self, in: context)

        try? context.save()
    }

    private static func applyReadingState(
        tier: SubscriptionTier,
        generatedCountInWindow: Int
    ) {
        setOnboardingCompleted(true)

        let context = ModelContext(Persistence.sharedModelContainer)
        let profile = resolveProfile(modelContext: context)
        profile.displayName = "UITest User"
        profile.applySubscriptionTier(tier, source: .localCache)

        let ledger = resolveLedger(userId: profile.userId, modelContext: context)
        ledger.articleWindowStart = Date().addingTimeInterval(-12 * 60 * 60)
        ledger.articlesGeneratedInWindow = max(0, generatedCountInWindow)
        ledger.activeWidgetProfileCount = 0
        ledger.touch()

        deleteAll(GeneratedContent.self, in: context)
        context.insert(makeSampleArticle())

        if (try? context.fetch(FetchDescriptor<InterestProfile>()).isEmpty) ?? true {
            context.insert(InterestProfile(selectedTags: ["Technology"]))
        }

        try? context.save()
    }

    private static func applyRegularUsageScenario(
        activeDays: Int = 28,
        wordsPerDay: Int = 2,
        articleBurstDay: Int = 28,
        articleBurstCount: Int = 4
    ) {
        setOnboardingCompleted(true)

        let context = ModelContext(Persistence.sharedModelContainer)
        let profile = resolveProfile(modelContext: context)
        profile.displayName = "Scenario User"
        profile.lexicalRank = 3400
        profile.easyRatingVelocity = 0.62
        profile.applySubscriptionTier(.premium, source: .localCache)

        let ledger = resolveLedger(userId: profile.userId, modelContext: context)
        ledger.articleWindowStart = Date()
        ledger.articlesGeneratedInWindow = 0
        ledger.activeWidgetProfileCount = 2
        ledger.touch()

        deleteAll(GeneratedContent.self, in: context)
        deleteAll(UserWordState.self, in: context)
        deleteAll(ReviewEvent.self, in: context)
        deleteAll(ReviewLog.self, in: context)
        deleteAll(DiscoveredLexeme.self, in: context)

        if let existingInterest = try? context.fetch(FetchDescriptor<InterestProfile>()).first {
            existingInterest.selectedTags = ["Technology", "Science", "Productivity"]
            existingInterest.lastUpdated = Date()
        } else {
            context.insert(InterestProfile(selectedTags: ["Technology", "Science", "Productivity"]))
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startDay = calendar.date(byAdding: .day, value: -(max(1, activeDays) - 1), to: startOfToday) else {
            try? context.save()
            return
        }

        let normalizedActiveDays = max(1, activeDays)
        let normalizedWordsPerDay = max(1, wordsPerDay)

        for dayOffset in 0..<normalizedActiveDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startDay) else { continue }

            for slot in 0..<normalizedWordsPerDay {
                let index = dayOffset * normalizedWordsPerDay + slot + 1
                let lemma = String(format: "scenario_word_%03d", index)
                let primaryGrade = index.isMultiple(of: 9) ? 4 : 3

                guard let primaryReviewDate = calendar.date(byAdding: .hour, value: 10 + (slot * 3), to: day),
                      let nextReviewDate = calendar.date(byAdding: .day, value: 3 + (index % 3), to: primaryReviewDate) else {
                    continue
                }

                let primaryEvent = ReviewEvent(
                    userId: profile.userId,
                    lemma: lemma,
                    grade: primaryGrade,
                    reviewDate: primaryReviewDate,
                    durationMs: 1100 + ((index % 5) * 140),
                    scheduledDays: Double(2 + (index % 4)),
                    reviewState: ReviewEvent.reviewState(for: primaryGrade)
                )
                context.insert(primaryEvent)

                let state = UserWordState(
                    userId: profile.userId,
                    lemma: lemma,
                    status: index.isMultiple(of: 5) ? .known : .learning,
                    stability: 4.0 + Double(index % 6),
                    difficulty: 0.32 + Double((index % 4)) * 0.07,
                    retrievability: 0.76 + Double((index % 3)) * 0.05,
                    nextReviewDate: nextReviewDate,
                    lastReviewDate: primaryReviewDate,
                    reviewCount: 1,
                    lapseCount: 0
                )
                context.insert(state)

                if index.isMultiple(of: 4),
                   let followUpReviewDate = calendar.date(byAdding: .hour, value: 8, to: primaryReviewDate) {
                    let followUpGrade = index.isMultiple(of: 8) ? 2 : 3
                    let followUpEvent = ReviewEvent(
                        userId: profile.userId,
                        lemma: lemma,
                        grade: followUpGrade,
                        reviewDate: followUpReviewDate,
                        durationMs: 900 + ((index % 3) * 130),
                        scheduledDays: Double(1 + (index % 2)),
                        reviewState: ReviewEvent.reviewState(for: followUpGrade)
                    )
                    context.insert(followUpEvent)
                    state.reviewCount += 1
                    state.lastReviewDate = followUpReviewDate
                    state.stability = max(2.5, state.stability + (followUpGrade >= 3 ? 0.8 : -1.2))
                    state.retrievability = max(0.45, min(0.98, state.retrievability + (followUpGrade >= 3 ? 0.06 : -0.18)))
                    state.lapseCount += followUpGrade < 3 ? 1 : 0
                    state.touch()
                }
            }
        }

        let burstDayOffset = min(max(0, articleBurstDay - 1), normalizedActiveDays - 1)
        let burstDay = calendar.date(byAdding: .day, value: burstDayOffset, to: startDay) ?? startOfToday
        let categories = ["Technology", "Science", "Culture", "Business"]
        let titles = [
            "The Future of Urban Farming",
            "Why Antifragile Systems Keep Improving",
            "How Attention Shapes Language Memory",
            "Tiny Habits That Compound Over Time"
        ]
        let articleFocusBank: [[String]] = [
            ["sustainable", "cultivate", "resilient"],
            ["insight", "retrospect", "synthesis"],
            ["perspective", "conspicuous", "inspect"],
            ["adaptive", "retention", "leverage"],
            ["contextual", "durable", "nuance"],
            ["inference", "coherent", "precision"]
        ]

        for articleIndex in 0..<max(1, articleBurstCount) {
            let title = titles[articleIndex % titles.count]
            let category = categories[articleIndex % categories.count]
            let words = articleFocusBank[(burstDayOffset + articleIndex) % articleFocusBank.count]
            let body = makeScenarioLongFormBody(
                title: title,
                category: category,
                focusWords: words
            )
            let createdAt = burstDay.addingTimeInterval(TimeInterval((18 + articleIndex) * 60 * 60))

            context.insert(
                GeneratedContent(
                    articleId: UUID().uuidString,
                    title: title,
                    bodyText: body,
                    targetWords: words,
                    category: category,
                    difficultyScore: 0.46 + (Double(articleIndex) * 0.03),
                    targetRank: 3000 + articleIndex * 140,
                    createdAt: createdAt,
                    isSaved: true
                )
            )
        }

        try? context.save()
    }

    private static func resolveProfile(modelContext: ModelContext) -> UserProfile {
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard

        if let storedUserID = defaults.string(forKey: UserProfile.activeUserDefaultsKey),
           let profile = fetchProfile(userId: storedUserID, modelContext: modelContext) {
            return profile
        }

        let descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        if let firstProfile = try? modelContext.fetch(descriptor).first {
            defaults.set(firstProfile.userId, forKey: UserProfile.activeUserDefaultsKey)
            return firstProfile
        }

        let fallbackProfile = UserProfile(userId: UserProfile.fallbackLocalUserID)
        modelContext.insert(fallbackProfile)
        defaults.set(fallbackProfile.userId, forKey: UserProfile.activeUserDefaultsKey)
        return fallbackProfile
    }

    private static func fetchProfile(userId: String, modelContext: ModelContext) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { profile in
                profile.userId == userId
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private static func resolveLedger(userId: String, modelContext: ModelContext) -> UsageLedger {
        let descriptor = FetchDescriptor<UsageLedger>(
            predicate: #Predicate { $0.userId == userId }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let created = UsageLedger(userId: userId)
        modelContext.insert(created)
        return created
    }

    private static func makeSampleArticle() -> GeneratedContent {
        let focusWords = ["sustainable", "cultivate", "resource"]
        return GeneratedContent(
            articleId: UUID().uuidString,
            title: "The Future of Urban Farming",
            bodyText: makeScenarioLongFormBody(
                title: "The Future of Urban Farming",
                category: "Technology",
                focusWords: focusWords
            ),
            targetWords: focusWords,
            category: "Technology",
            difficultyScore: 0.42,
            targetRank: 2400,
            createdAt: Date(),
            isSaved: true
        )
    }

    private static func makeScenarioLongFormBody(
        title: String,
        category: String,
        focusWords: [String]
    ) -> String {
        let normalizedCategory = category.lowercased()
        let focusSentence = focusWords.isEmpty
            ? "Use the article to connect concepts across multiple paragraphs and summarize from memory."
            : "Pay attention to these focus words as they reappear in context: \(focusWords.joined(separator: ", "))."

        let intro = """
        In this reading, we explore \(normalizedCategory) through a retrieval-first learning lens. Instead of isolated snippets, the article stays with one coherent theme long enough to build useful understanding. \(focusSentence) The goal is practical fluency: after reading, you should be able to explain the core argument, describe one trade-off, and use new vocabulary in your own sentence.
        """

        let reusableParagraphs = [
            """
            Strong learning sessions start with a clear question. When readers begin with a question, they evaluate each paragraph for relevance instead of treating every sentence as equally important. This improves both speed and retention. In long-form reading, relevance acts like a filter that reduces mental noise and strengthens recall. The filter also supports motivation, because readers can feel progress as each section answers part of the original question.
            """,
            """
            Coherent explanations usually follow a pattern: define a concept, illustrate it with one concrete example, then compare it to a nearby alternative. This pattern helps intermediate learners because it makes boundaries visible. Words are easier to remember when their boundaries are explicit. If a term is introduced without boundaries, it may feel familiar during reading but collapse during speaking. Boundaries prevent that collapse.
            """,
            """
            Retrieval after each section is where fluency grows. A short pause and one-sentence summary forces the brain to reconstruct meaning. Reconstruction is effortful, but that effort is exactly what strengthens memory. Passive rereading feels smooth but fades quickly. Active recall feels slower but compounds over time. Learners who accept this short discomfort usually see better performance in review sessions.
            """,
            """
            Topic interest matters, yet structure matters more than excitement. A highly engaging article can still be hard to learn from if transitions are unclear. Effective educational writing uses predictable transitions so readers can track cause, consequence, and contrast. Predictability does not mean boring; it means the reader spends energy on meaning rather than decoding confusing jumps.
            """,
            """
            Vocabulary depth increases when words appear in varied functions. A word introduced in description should later appear in comparison and decision-making. This variation teaches flexibility. Flexible vocabulary is more durable than memorized definitions because it is linked to reasoning patterns, not just isolated facts. Over several weeks, flexible knowledge transfers better to conversations and writing tasks.
            """,
            """
            A practical close to each reading session is three lines of output: one summary line, one critique line, and one application line. This converts comprehension into production and exposes weak points immediately. If production feels difficult, that is useful information, not failure. It means the next review can be targeted and efficient.
            """
        ]

        var paragraphs: [String] = [intro]
        var idx = 0
        while estimatedWordCount(in: paragraphs.joined(separator: " ")) < 330 {
            paragraphs.append(reusableParagraphs[idx % reusableParagraphs.count])
            idx += 1
        }

        let closing = """
        In short, cohesive reading creates space for attention, retrieval, and transfer to work together. This is why the article stays concise but complete: enough context for recall, without unnecessary length.
        """
        paragraphs.append(closing)

        return paragraphs.joined(separator: "\n\n")
    }

    private static func estimatedWordCount(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        let descriptor = FetchDescriptor<T>()
        guard let models = try? context.fetch(descriptor) else { return }
        for model in models {
            context.delete(model)
        }
    }
}
