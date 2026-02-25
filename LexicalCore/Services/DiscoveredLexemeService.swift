import Foundation
import SwiftData

public struct DiscoveredLexemeCandidate: Sendable, Equatable {
    public let lemma: String
    public let definition: String?
    public let partOfSpeech: String?
    public let ipa: String?
    public let synonyms: [String]
    public let exampleSentences: [String]
    public let confidence: Double?

    public init(
        lemma: String,
        definition: String? = nil,
        partOfSpeech: String? = nil,
        ipa: String? = nil,
        synonyms: [String] = [],
        exampleSentences: [String] = [],
        confidence: Double? = nil
    ) {
        self.lemma = lemma
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.ipa = ipa
        self.synonyms = synonyms
        self.exampleSentences = exampleSentences
        self.confidence = confidence
    }
}

public struct DiscoveredLexemeIngestionService {
    public init() {}

    @discardableResult
    public func ingest(
        candidates: [DiscoveredLexemeCandidate],
        sourceArticleId: String?,
        modelContext: ModelContext,
        userId: String,
        now: Date = Date()
    ) throws -> Int {
        let normalized = normalizedCandidates(candidates)
        guard !normalized.isEmpty else { return 0 }

        let descriptor = FetchDescriptor<DiscoveredLexeme>(
            predicate: #Predicate { row in
                row.userId == userId
            }
        )
        let existingRows = try modelContext.fetch(descriptor)
        var existingByKey: [String: DiscoveredLexeme] = [:]
        existingByKey.reserveCapacity(existingRows.count)
        for row in existingRows {
            existingByKey[row.userLemmaKey] = row
        }

        var changed = 0
        let normalizedSourceId = normalizedString(sourceArticleId)

        for candidate in normalized {
            let key = DiscoveredLexeme.makeKey(userId: userId, lemma: candidate.lemma)

            if let row = existingByKey[key] {
                if isEmpty(row.definition), let definition = candidate.definition {
                    row.definition = definition
                } else if let definition = candidate.definition {
                    row.definition = preferredText(current: row.definition, incoming: definition)
                }

                if isEmpty(row.partOfSpeech), let partOfSpeech = candidate.partOfSpeech {
                    row.partOfSpeech = partOfSpeech
                }
                if isEmpty(row.ipa), let ipa = candidate.ipa {
                    row.ipa = ipa
                }

                row.synonyms = mergeUnique(
                    base: row.synonyms,
                    incoming: candidate.synonyms,
                    maxCount: nil
                )
                row.exampleSentences = mergeUnique(
                    base: row.exampleSentences,
                    incoming: candidate.exampleSentences,
                    maxCount: nil
                )
                row.recordSeen(
                    sourceArticleId: normalizedSourceId,
                    confidence: candidate.confidence,
                    now: now
                )
                changed += 1
                continue
            }

            let created = DiscoveredLexeme(
                userId: userId,
                lemma: candidate.lemma,
                partOfSpeech: candidate.partOfSpeech,
                ipa: candidate.ipa,
                definition: candidate.definition,
                synonyms: candidate.synonyms,
                exampleSentences: candidate.exampleSentences,
                sourceArticleId: normalizedSourceId,
                confidence: candidate.confidence ?? 0.55,
                firstSeenAt: now,
                lastSeenAt: now,
                seenCount: 1
            )
            modelContext.insert(created)
            existingByKey[key] = created
            changed += 1
        }

        if changed > 0 {
            try modelContext.save()
        }

        return changed
    }

    private func normalizedCandidates(_ candidates: [DiscoveredLexemeCandidate]) -> [DiscoveredLexemeCandidate] {
        var mergedByLemma: [String: DiscoveredLexemeCandidate] = [:]

        for raw in candidates {
            guard let lemma = normalizedLemma(raw.lemma) else { continue }

            let definition = normalizedString(raw.definition)
            let partOfSpeech = normalizedPartOfSpeech(raw.partOfSpeech)
            let ipa = normalizedString(raw.ipa)
            let synonyms = sanitizedTerms(raw.synonyms, excluding: lemma, maxCount: nil)
            let examples = sanitizedSentences(raw.exampleSentences, maxCount: nil)
            let confidence = raw.confidence.map(clampConfidence)

            // Quality gate: keep only candidates that carry meaningful lexical payload.
            guard definition != nil || !examples.isEmpty else { continue }

            let candidate = DiscoveredLexemeCandidate(
                lemma: lemma,
                definition: definition,
                partOfSpeech: partOfSpeech,
                ipa: ipa,
                synonyms: synonyms,
                exampleSentences: examples,
                confidence: confidence
            )

            if let existing = mergedByLemma[lemma] {
                mergedByLemma[lemma] = mergeCandidates(existing: existing, incoming: candidate)
            } else {
                mergedByLemma[lemma] = candidate
            }
        }

        return Array(mergedByLemma.values)
    }

    private func mergeCandidates(
        existing: DiscoveredLexemeCandidate,
        incoming: DiscoveredLexemeCandidate
    ) -> DiscoveredLexemeCandidate {
        DiscoveredLexemeCandidate(
            lemma: existing.lemma,
            definition: preferredText(current: existing.definition, incoming: incoming.definition),
            partOfSpeech: existing.partOfSpeech ?? incoming.partOfSpeech,
            ipa: existing.ipa ?? incoming.ipa,
            synonyms: mergeUnique(base: existing.synonyms, incoming: incoming.synonyms, maxCount: nil),
            exampleSentences: mergeUnique(base: existing.exampleSentences, incoming: incoming.exampleSentences, maxCount: nil),
            confidence: max(existing.confidence ?? 0.0, incoming.confidence ?? 0.0)
        )
    }

    private func normalizedLemma(_ lemma: String) -> String? {
        let normalized = lemma
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalized.count >= 2, normalized.count <= 40 else { return nil }
        guard !normalized.contains(" ") else { return nil }

        for scalar in normalized.unicodeScalars {
            let value = scalar.value
            let isAsciiLower = value >= 97 && value <= 122
            let isApostrophe = value == 39
            let isHyphen = value == 45
            guard isAsciiLower || isApostrophe || isHyphen else { return nil }
        }

        return normalized
    }

    private func normalizedString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func normalizedPartOfSpeech(_ value: String?) -> String? {
        normalizedString(value)?.lowercased()
    }

    private func sanitizedTerms(
        _ values: [String],
        excluding lemma: String,
        maxCount: Int?
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let limit = maxCount.map { max(1, $0) } ?? Int.max
        result.reserveCapacity(maxCount ?? values.count)

        for value in values {
            guard let term = normalizedString(value) else { continue }
            guard ContentSafetyService.isSafeText(term) else { continue }
            let key = term.lowercased()
            guard key != lemma, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(term)
            if result.count >= limit { break }
        }
        return result
    }

    private func sanitizedSentences(_ values: [String], maxCount: Int?) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let limit = maxCount.map { max(1, $0) } ?? Int.max
        result.reserveCapacity(maxCount ?? values.count)

        for value in values {
            guard let sentence = normalizedString(value) else { continue }
            guard ContentSafetyService.isSafeText(sentence) else { continue }
            let key = sentence.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(sentence)
            if result.count >= limit { break }
        }
        return result
    }

    private func mergeUnique(base: [String], incoming: [String], maxCount: Int?) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let values = base + incoming
        let limit = maxCount.map { max(1, $0) } ?? Int.max
        result.reserveCapacity(maxCount ?? values.count)

        for value in values {
            let key = value.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(value)
            if result.count >= limit { break }
        }
        return result
    }

    private func preferredText(current: String?, incoming: String?) -> String? {
        guard let incoming else { return current }
        guard let current else { return incoming }
        return incoming.count > current.count ? incoming : current
    }

    private func isEmpty(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    private func clampConfidence(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }
}

public struct LexemePromotionService {
    public init() {}

    public func discoveredLexeme(
        lemma: String,
        userId: String,
        modelContext: ModelContext
    ) throws -> DiscoveredLexeme? {
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = DiscoveredLexeme.makeKey(userId: userId, lemma: normalizedLemma)
        let descriptor = FetchDescriptor<DiscoveredLexeme>(
            predicate: #Predicate { row in
                row.userLemmaKey == key
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    public func upsertCanonicalLexeme(
        lemma: String,
        userId: String,
        fallbackDefinition: String? = nil,
        fallbackSentence: String? = nil,
        modelContext: ModelContext
    ) throws -> LexemeDefinition {
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let lexemeDescriptor = FetchDescriptor<LexemeDefinition>(
            predicate: #Predicate { row in
                row.lemma == normalizedLemma
            }
        )
        let discovered = try discoveredLexeme(
            lemma: normalizedLemma,
            userId: userId,
            modelContext: modelContext
        )

        let definition = firstNonEmpty(
            discovered?.definition,
            fallbackDefinition
        )
        let sentence = firstNonEmpty(
            discovered?.exampleSentences.first,
            fallbackSentence
        )

        if let existing = try modelContext.fetch(lexemeDescriptor).first {
            if isEmpty(existing.basicMeaning) {
                existing.basicMeaning = definition
            }
            if isEmpty(existing.sampleSentence) {
                existing.sampleSentence = sentence
            }
            if isEmpty(existing.partOfSpeech), let pos = discovered?.partOfSpeech {
                existing.partOfSpeech = pos
            }
            if isEmpty(existing.ipa), let ipa = discovered?.ipa {
                existing.ipa = ipa
            }
            discovered?.markPromoted()
            return existing
        }

        let created = LexemeDefinition(
            lemma: normalizedLemma,
            seedId: nil,
            rank: nil,
            cefrLevel: nil,
            partOfSpeech: discovered?.partOfSpeech,
            ipa: discovered?.ipa,
            basicMeaning: definition,
            sampleSentence: sentence
        )
        modelContext.insert(created)
        discovered?.markPromoted()
        return created
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private func isEmpty(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
}
