import Foundation
import SwiftData

public enum LexicalSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            VocabularyItem.self,
            ReviewLog.self,
            InterestProfile.self,
            MorphologicalRoot.self,
            UserProfile.self,
        ]
    }
}

public enum LexicalSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            LexemeDefinition.self,
            VocabularyItem.self,
            UserWordState.self,
            ReviewEvent.self,
            ReviewLog.self,
            InterestProfile.self,
            MorphologicalRoot.self,
            UserProfile.self,
        ]
    }
}

public enum LexicalSchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(3, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            LexemeDefinition.self,
            UserWordState.self,
            ReviewEvent.self,
            InterestProfile.self,
            MorphologicalRoot.self,
            UserProfile.self,
        ]
    }
}

public enum LexicalSchemaV4: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(4, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            LexemeDefinition.self,
            UserWordState.self,
            ReviewEvent.self,
            InterestProfile.self,
            MorphologicalRoot.self,
            UserProfile.self,
            GeneratedContent.self,
        ]
    }
}

public enum LexicalMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [
            LexicalSchemaV1.self,
            LexicalSchemaV2.self,
            LexicalSchemaV3.self,
            LexicalSchemaV4.self
        ]
    }

    public static var stages: [MigrationStage] {
        [
            .custom(
                fromVersion: LexicalSchemaV1.self,
                toVersion: LexicalSchemaV2.self,
                willMigrate: nil,
                didMigrate: { modelContext in
                    try backfillDualStore(in: modelContext)
                }
            ),
            .lightweight(
                fromVersion: LexicalSchemaV2.self,
                toVersion: LexicalSchemaV3.self
            ),
            .lightweight(
                fromVersion: LexicalSchemaV3.self,
                toVersion: LexicalSchemaV4.self
            ),
        ]
    }

    private static func backfillDualStore(in modelContext: ModelContext) throws {
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        let activeUserId = try ensureActiveUser(modelContext: modelContext, defaults: defaults)

        let existingLexemes = try modelContext.fetch(FetchDescriptor<LexemeDefinition>())
        var lexemeByLemma: [String: LexemeDefinition] = [:]
        lexemeByLemma.reserveCapacity(existingLexemes.count)
        for lexeme in existingLexemes {
            lexemeByLemma[lexeme.lemma] = lexeme
        }

        let existingStates = try modelContext.fetch(FetchDescriptor<UserWordState>())
        var stateByKey: [String: UserWordState] = [:]
        stateByKey.reserveCapacity(existingStates.count)
        for state in existingStates {
            stateByKey[state.userLemmaKey] = state
        }

        let existingEvents = try modelContext.fetch(FetchDescriptor<ReviewEvent>())
        var eventIds = Set(existingEvents.map(\.eventId))
        eventIds.reserveCapacity(existingEvents.count + 1024)

        let legacyItems = try modelContext.fetch(FetchDescriptor<VocabularyItem>())
        var lexemeInserted = 0
        var stateInserted = 0
        var stateUpdated = 0

        for item in legacyItems {
            let lemma = item.lemma.lowercased()

            if lexemeByLemma[lemma] == nil {
                let lexeme = LexemeDefinition(
                    lemma: lemma,
                    seedId: nil,
                    rank: nil,
                    cefrLevel: nil,
                    partOfSpeech: nil,
                    ipa: nil,
                    basicMeaning: normalizedString(item.definition),
                    sampleSentence: normalizedString(item.contextSentence)
                )
                modelContext.insert(lexeme)
                lexemeByLemma[lemma] = lexeme
                lexemeInserted += 1
            }

            let key = UserWordState.makeKey(userId: activeUserId, lemma: lemma)
            let state: UserWordState
            if let existingState = stateByKey[key] {
                state = existingState
                stateUpdated += 1
            } else {
                state = UserWordState(userId: activeUserId, lemma: lemma)
                modelContext.insert(state)
                stateByKey[key] = state
                stateInserted += 1
            }

            state.stability = item.stability
            state.difficulty = item.difficulty
            state.retrievability = item.retrievability
            state.nextReviewDate = item.nextReviewDate
            state.lastReviewDate = item.lastReviewedAt
            state.reviewCount = item.reviewCount
            state.status = statusFor(item)
            state.touch()
        }

        let legacyLogs = try modelContext.fetch(FetchDescriptor<ReviewLog>())
        var eventsInserted = 0
        for log in legacyLogs {
            guard let lemma = log.vocabularyItem?.lemma.lowercased() else { continue }
            let eventId = log.id.uuidString
            guard !eventIds.contains(eventId) else { continue }

            let scheduledDays = scheduledDaysFromLegacyLog(log)
            let event = ReviewEvent(
                eventId: eventId,
                userId: activeUserId,
                lemma: lemma,
                grade: log.grade,
                reviewDate: log.reviewDate,
                durationMs: Int(log.duration * 1000.0),
                scheduledDays: scheduledDays,
                reviewState: ReviewEvent.reviewState(for: log.grade),
                deviceId: log.deviceId,
                sourceReviewLogId: log.id
            )
            modelContext.insert(event)
            eventIds.insert(eventId)
            eventsInserted += 1
        }

        if lexemeInserted > 0 || stateInserted > 0 || stateUpdated > 0 || eventsInserted > 0 {
            try modelContext.save()
            print(
                "LexicalMigrationPlan: backfill complete " +
                "lexemes=\(lexemeInserted) " +
                "states(inserted=\(stateInserted), updated=\(stateUpdated)) " +
                "events=\(eventsInserted)"
            )
        }
    }

    private static func ensureActiveUser(
        modelContext: ModelContext,
        defaults: UserDefaults
    ) throws -> String {
        let profiles = try modelContext.fetch(
            FetchDescriptor<UserProfile>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )

        if let storedUserId = defaults.string(forKey: UserProfile.activeUserDefaultsKey),
           profiles.contains(where: { $0.userId == storedUserId }) {
            return storedUserId
        }

        if let firstProfile = profiles.first {
            defaults.set(firstProfile.userId, forKey: UserProfile.activeUserDefaultsKey)
            return firstProfile.userId
        }

        let profile = UserProfile(userId: UserProfile.fallbackLocalUserID)
        modelContext.insert(profile)
        try modelContext.save()
        defaults.set(profile.userId, forKey: UserProfile.activeUserDefaultsKey)
        return profile.userId
    }

    private static func statusFor(_ item: VocabularyItem) -> UserWordStatus {
        if item.stability >= 90 {
            return .known
        }
        if item.reviewCount > 0 {
            return .learning
        }
        return .new
    }

    private static func normalizedString(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func scheduledDaysFromLegacyLog(_ log: ReviewLog) -> Double {
        guard let nextReviewDate = log.vocabularyItem?.nextReviewDate else {
            return 0
        }
        return max(0, nextReviewDate.timeIntervalSince(log.reviewDate) / 86_400.0)
    }
}
