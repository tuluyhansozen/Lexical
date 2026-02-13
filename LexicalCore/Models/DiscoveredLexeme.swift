import Foundation
import SwiftData

/// User-scoped lexeme candidates discovered from generated article payloads.
/// These remain separate from canonical `LexemeDefinition` until promoted.
@Model
public final class DiscoveredLexeme {
    /// Composite uniqueness key: "\(userId)|\(lemma)"
    @Attribute(.unique) public var userLemmaKey: String

    public var userId: String
    public var lemma: String

    public var partOfSpeech: String?
    public var ipa: String?
    public var definition: String?
    public var synonyms: [String]
    public var exampleSentences: [String]

    public var sourceArticleId: String?
    public var confidence: Double
    public var seenCount: Int
    public var firstSeenAt: Date
    public var lastSeenAt: Date
    public var promotedAt: Date?
    public var updatedAt: Date

    public init(
        userId: String,
        lemma: String,
        partOfSpeech: String? = nil,
        ipa: String? = nil,
        definition: String? = nil,
        synonyms: [String] = [],
        exampleSentences: [String] = [],
        sourceArticleId: String? = nil,
        confidence: Double = 0.55,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        seenCount: Int = 1
    ) {
        let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.userId = normalizedUserId
        self.lemma = normalizedLemma
        self.userLemmaKey = Self.makeKey(userId: normalizedUserId, lemma: normalizedLemma)
        self.partOfSpeech = partOfSpeech
        self.ipa = ipa
        self.definition = definition
        self.synonyms = synonyms
        self.exampleSentences = exampleSentences
        self.sourceArticleId = sourceArticleId
        self.confidence = max(0.0, min(1.0, confidence))
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.seenCount = max(1, seenCount)
        self.updatedAt = Date()
    }

    public static func makeKey(userId: String, lemma: String) -> String {
        let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedUserId)|\(normalizedLemma)"
    }

    public func recordSeen(
        sourceArticleId: String?,
        confidence: Double?,
        now: Date = Date()
    ) {
        seenCount += 1
        lastSeenAt = now
        if let sourceArticleId, !sourceArticleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.sourceArticleId = sourceArticleId
        }
        if let confidence {
            self.confidence = max(self.confidence, max(0.0, min(1.0, confidence)))
        }
        updatedAt = now
    }

    public func markPromoted(now: Date = Date()) {
        promotedAt = now
        updatedAt = now
    }
}
