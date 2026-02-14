import Foundation
import SwiftData
import LexicalCore

enum E2ETestLaunchConfigurator {
    static let baseFlag = "--lexical-ui-tests"

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

        if arguments.contains("--lexical-e2e-free-limit") {
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
        GeneratedContent(
            articleId: UUID().uuidString,
            title: "The Future of Urban Farming",
            bodyText: "As cities grow, sustainable food production is becoming a core urban challenge. Vertical farming lets growers cultivate crops close to demand with lower transport overhead and tighter resource controls.",
            targetWords: ["sustainable", "cultivate", "resource"],
            category: "Technology",
            difficultyScore: 0.42,
            targetRank: 2400,
            createdAt: Date(),
            isSaved: true
        )
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        let descriptor = FetchDescriptor<T>()
        guard let models = try? context.fetch(descriptor) else { return }
        for model in models {
            context.delete(model)
        }
    }
}
