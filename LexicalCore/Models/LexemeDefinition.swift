import Foundation
import SwiftData

/// Canonical lexical data loaded from seed files (read-mostly domain data).
@Model
public final class LexemeDefinition {
    /// Stable lemma identifier used as the canonical lookup key.
    @Attribute(.unique) public var lemma: String

    /// Optional source ID from seed_data.json
    public var seedId: Int?
    public var rank: Int?
    public var cefrLevel: String?
    public var partOfSpeech: String?
    public var ipa: String?
    public var basicMeaning: String?
    public var sampleSentence: String?
    public var sourceUpdatedAt: Date

    public init(
        lemma: String,
        seedId: Int? = nil,
        rank: Int? = nil,
        cefrLevel: String? = nil,
        partOfSpeech: String? = nil,
        ipa: String? = nil,
        basicMeaning: String? = nil,
        sampleSentence: String? = nil
    ) {
        self.lemma = lemma.lowercased()
        self.seedId = seedId
        self.rank = rank
        self.cefrLevel = cefrLevel
        self.partOfSpeech = partOfSpeech
        self.ipa = ipa
        self.basicMeaning = basicMeaning
        self.sampleSentence = sampleSentence
        self.sourceUpdatedAt = Date()
    }
}
