import Foundation
import SwiftData

public struct NotificationTriagePayload {
    public let lemma: String?
    public let definition: String?
    public let rank: Int?

    public init(lemma: String?, definition: String?, rank: Int?) {
        self.lemma = lemma
        self.definition = definition
        self.rank = rank
    }

    public var normalizedLemma: String? {
        let normalized = lemma?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return (normalized?.isEmpty == false) ? normalized : nil
    }
}

/// Encapsulates actionable-notification triage behavior (reveal/add/ignore) for reuse.
public struct NotificationTriageService {
    public init() {}

    public func payload(from userInfo: [AnyHashable: Any]) -> NotificationTriagePayload {
        let lemma = userInfo["lemma"] as? String
        let definition = userInfo["definition"] as? String
        let rank = numericValue(userInfo["rank"])
        return NotificationTriagePayload(lemma: lemma, definition: definition, rank: rank)
    }

    public func rewardMultiplier(
        candidateRank: Int?,
        lexicalRank: Int,
        tolerance: Int = 400,
        alignedMultiplier: Double = 1.5
    ) -> Double {
        guard let candidateRank else { return 1.0 }
        return abs(candidateRank - lexicalRank) <= tolerance ? alignedMultiplier : 1.0
    }

    public func stagePromptRoute(_ payload: NotificationTriagePayload) {
        guard let lemma = payload.normalizedLemma else { return }

        let defaults = UserDefaults.standard
        defaults.set(lemma, forKey: "lexical.pending_prompt_lemma")

        if let definition = payload.definition,
           !definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(definition, forKey: "lexical.pending_prompt_definition")
        } else {
            defaults.removeObject(forKey: "lexical.pending_prompt_definition")
        }

        NotificationCenter.default.post(
            name: .lexicalOpenPromptCard,
            object: nil,
            userInfo: [
                "lemma": lemma,
                "definition": payload.definition as Any
            ]
        )
    }

    @MainActor
    @discardableResult
    public func addToDeck(
        _ payload: NotificationTriagePayload,
        modelContext: ModelContext
    ) throws -> String? {
        guard let lemma = payload.normalizedLemma else { return nil }

        let activeUser = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let promotionService = LexemePromotionService()
        _ = try promotionService.upsertCanonicalLexeme(
            lemma: lemma,
            userId: activeUser.userId,
            fallbackDefinition: payload.definition,
            modelContext: modelContext
        )

        let key = UserWordState.makeKey(userId: activeUser.userId, lemma: lemma)
        let stateDescriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        let state = (try modelContext.fetch(stateDescriptor).first) ?? {
            let created = UserWordState(userId: activeUser.userId, lemma: lemma, status: .learning)
            modelContext.insert(created)
            return created
        }()

        state.status = .learning
        state.nextReviewDate = Date()
        if state.reviewCount == 0 {
            state.stability = max(0.2, state.stability)
            state.difficulty = max(0.3, state.difficulty)
            state.retrievability = max(0.25, state.retrievability)
        }
        state.touch()

        try modelContext.save()
        return lemma
    }

    @MainActor
    @discardableResult
    public func ignoreWord(
        _ payload: NotificationTriagePayload,
        modelContext: ModelContext
    ) throws -> String? {
        guard let lemma = payload.normalizedLemma else { return nil }

        let activeUser = UserProfile.resolveActiveProfile(modelContext: modelContext)
        activeUser.markIgnored(lemma)

        let key = UserWordState.makeKey(userId: activeUser.userId, lemma: lemma)
        let descriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        let state = (try modelContext.fetch(descriptor).first) ?? {
            let created = UserWordState(userId: activeUser.userId, lemma: lemma, status: .ignored)
            modelContext.insert(created)
            return created
        }()

        state.status = .ignored
        state.touch()

        try modelContext.save()
        return lemma
    }

    private func numericValue(_ raw: Any?) -> Int? {
        if let intValue = raw as? Int { return intValue }
        if let stringValue = raw as? String { return Int(stringValue) }
        if let numberValue = raw as? NSNumber { return numberValue.intValue }
        return nil
    }
}
