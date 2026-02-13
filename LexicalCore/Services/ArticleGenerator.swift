import Foundation
import SwiftData

/// Interface for the LLM that generates content.
public protocol ArticleLLMProvider {
    func generateContent(prompt: String) async throws -> String
}

/// Simulation provider for development without a remote backend.
public final class MockLLMProvider: ArticleLLMProvider {
    public init() {}

    public func generateContent(prompt: String) async throws -> String {
        try await Task.sleep(nanoseconds: 700_000_000)

        return """
        TITLE: The Future of Urban Farming

        As cities grow, sustainable food production is becoming a core urban challenge. Vertical farming lets growers cultivate crops close to consumers while reducing land use and transportation waste. Engineers are improving lighting systems and closed-loop irrigation to lower energy and water costs. As these systems mature, urban farming can turn empty warehouses into productive, resilient food infrastructure.
        """
    }
}

/// Retries transient provider failures with exponential backoff.
public final class RetryingLLMProvider: ArticleLLMProvider {
    private let base: ArticleLLMProvider
    private let maxAttempts: Int
    private let initialDelayMs: UInt64

    public init(
        base: ArticleLLMProvider,
        maxAttempts: Int = 3,
        initialDelayMs: UInt64 = 600
    ) {
        self.base = base
        self.maxAttempts = max(1, maxAttempts)
        self.initialDelayMs = max(100, initialDelayMs)
    }

    public func generateContent(prompt: String) async throws -> String {
        var attempt = 0
        var delay = initialDelayMs
        var lastError: Error?

        while attempt < maxAttempts {
            do {
                return try await base.generateContent(prompt: prompt)
            } catch {
                lastError = error
                attempt += 1
                guard attempt < maxAttempts, Self.isRetryable(error) else { break }
                try await Task.sleep(nanoseconds: delay * 1_000_000)
                delay = min(delay * 2, 4_000)
            }
        }

        throw lastError ?? RemoteArticleServiceError.invalidResponse
    }

    private static func isRetryable(_ error: Error) -> Bool {
        if let remoteError = error as? RemoteArticleServiceError {
            switch remoteError {
            case let .httpError(statusCode, _):
                return statusCode == 429 || (500...599).contains(statusCode)
            case .invalidResponse, .emptyContent:
                return true
            case .missingEndpoint:
                return false
            }
        }
        return true
    }
}

/// Uses a fallback provider when the primary provider fails.
public final class FallbackLLMProvider: ArticleLLMProvider {
    private let primary: ArticleLLMProvider
    private let fallback: ArticleLLMProvider

    public init(primary: ArticleLLMProvider, fallback: ArticleLLMProvider) {
        self.primary = primary
        self.fallback = fallback
    }

    public func generateContent(prompt: String) async throws -> String {
        do {
            return try await primary.generateContent(prompt: prompt)
        } catch {
            return try await fallback.generateContent(prompt: prompt)
        }
    }
}

public enum ArticleLLMProviderFactory {
    /// Returns a production-ready provider when env config exists, otherwise a mock provider.
    public static func makeDefaultProvider() -> ArticleLLMProvider {
        guard let remote = RemoteArticleService.fromEnvironment() else {
            return MockLLMProvider()
        }
        let retrying = RetryingLLMProvider(base: remote, maxAttempts: 3)
        return FallbackLLMProvider(primary: retrying, fallback: MockLLMProvider())
    }
}

public actor ArticleGenerator {
    private let store: ArticleStore
    private let evaluator: ArticleConstraintsEvaluator
    private let llmProvider: ArticleLLMProvider
    private let promptBuilder: AdaptivePromptBuilder
    private let discoveredLexemeIngestionService: DiscoveredLexemeIngestionService

    public init(
        store: ArticleStore,
        evaluator: ArticleConstraintsEvaluator = .init(),
        llmProvider: ArticleLLMProvider = MockLLMProvider(),
        promptBuilder: AdaptivePromptBuilder = .init(),
        discoveredLexemeIngestionService: DiscoveredLexemeIngestionService = .init()
    ) {
        self.store = store
        self.evaluator = evaluator
        self.llmProvider = llmProvider
        self.promptBuilder = promptBuilder
        self.discoveredLexemeIngestionService = discoveredLexemeIngestionService
    }

    /// Generates a new article personalized to the user.
    public func generateArticle(
        profile: InterestProfile,
        targetWords: [String],
        reinforcementWords: [String] = [],
        stretchWords: [String] = [],
        adaptiveContext: AdaptivePromptContext? = nil,
        knownWords: [String] = []
    ) async throws -> GeneratedArticle {
        _ = knownWords
        let theme = selectTheme(from: profile)
        let constructedPrompt = constructPrompt(
            theme: theme,
            targets: targetWords,
            reinforcementWords: reinforcementWords,
            stretchWords: stretchWords,
            adaptiveContext: adaptiveContext
        )
        let rawResponse = try await llmProvider.generateContent(prompt: constructedPrompt.body)
        let parsed = parseResponse(rawResponse)
        let title = parsed.title
        let content = parsed.bodyText

        let wordCount = content.split(separator: " ").count
        let responseTargets = parsed.declaredFocusWords.isEmpty ? targetWords : parsed.declaredFocusWords
        let containedTargets = responseTargets.filter { content.localizedCaseInsensitiveContains($0) }
        let validation = evaluator.evaluate(
            text: content,
            newWordCount: containedTargets.count,
            totalWordCount: wordCount
        )

        if !validation.isValid {
            print("Article generated with issues: \(validation.issues)")
        }

        let article = GeneratedArticle(
            title: title,
            content: content,
            targetWords: containedTargets,
            category: theme,
            difficultyScore: validation.score,
            targetRank: constructedPrompt.centerRank
        )

        try await store.save(article)
        try await ingestDiscoveredLexemes(
            parsed.discoveredLexemes,
            sourceArticleId: article.id.uuidString
        )
        return article
    }

    private func selectTheme(from profile: InterestProfile) -> String {
        let weights = profile.categoryWeights
        let total = weights.values.reduce(0, +)

        if total == 0 {
            return profile.selectedTags.randomElement() ?? "General Science"
        }

        let randomValue = Double.random(in: 0..<total)
        var cumulative = 0.0
        for (category, weight) in weights {
            cumulative += weight
            if randomValue <= cumulative {
                return category
            }
        }
        return "Technology"
    }

    private func constructPrompt(
        theme: String,
        targets: [String],
        reinforcementWords: [String],
        stretchWords: [String],
        adaptiveContext: AdaptivePromptContext?
    ) -> ConstructedPrompt {
        let templatePrompt = templatePrompt(
            theme: theme,
            targets: targets,
            reinforcementWords: reinforcementWords,
            stretchWords: stretchWords
        )

        guard let adaptiveContext else {
            return ConstructedPrompt(
                body: templatePrompt,
                centerRank: nil
            )
        }

        let adaptive = promptBuilder.buildPrompt(
            context: adaptiveContext,
            focusLemmas: targets,
            topic: theme,
            baseTemplate: templatePrompt
        )

        return ConstructedPrompt(
            body: adaptive.body,
            centerRank: adaptive.centerRank
        )
    }

    private func templatePrompt(
        theme: String,
        targets: [String],
        reinforcementWords: [String],
        stretchWords: [String]
    ) -> String {
        let reinforcementText = reinforcementWords.isEmpty ? "none" : reinforcementWords.joined(separator: ", ")
        let stretchText = stretchWords.isEmpty ? "none" : stretchWords.joined(separator: ", ")

        if let url = Bundle.main.url(forResource: "ArticleTemplateBank", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let bank = try? JSONDecoder().decode([String: [Template]].self, from: data),
           let templates = bank["templates"] {
            let template = templates.first { $0.category.lowercased() == theme.lowercased() }
                ?? templates.first { $0.category == "General" }

            if let template {
                return template.prompt_structure
                    .replacingOccurrences(of: "[THEME]", with: theme)
                    .replacingOccurrences(of: "[TARGETS]", with: targets.joined(separator: ", "))
                    + """

                    Output STRICT JSON with keys:
                    - title: string
                    - body_text: string
                    - used_reinforcement_words: string[]
                    - used_stretch_words: string[]
                    - glossary: array of objects with keys
                      lemma, definition, part_of_speech, ipa, synonyms, examples, confidence

                    Glossary rules:
                    - Include all required target lemmas.
                    - You may add up to 4 additional context words likely useful for learning.
                    - Keep entries factual and concise.
                    - Reinforcement words (must be present): \(reinforcementText)
                    - Stretch words (must be present): \(stretchText)
                    """
            }
        }

        return """
        Write a short article about \(theme).
        Target constraints:
        - Include these words explicitly: \(targets.joined(separator: ", "))
        - Reinforcement words (must be present): \(reinforcementText)
        - Stretch words (must be present): \(stretchText)
        - Length: 150-300 words.
        - Tone: Engaging and educational.
        - Output strict JSON with keys:
          "title", "body_text", "used_reinforcement_words", "used_stretch_words", "glossary".
        - Each glossary item must include:
          "lemma", "definition", "part_of_speech", "ipa", "synonyms", "examples", "confidence".
        """
    }

    private func parseResponse(_ response: String) -> ParsedArticleResponse {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let title = normalizedString(json["title"] as? String) ?? "Generated Article"
            let body = normalizedString(
                (json["body_text"] as? String) ??
                (json["body"] as? String) ??
                (json["content"] as? String)
            )
            if let body {
                return ParsedArticleResponse(
                    title: title,
                    bodyText: body,
                    discoveredLexemes: extractDiscoveredLexemes(from: json),
                    declaredFocusWords: extractDeclaredFocusWords(from: json)
                )
            }
        }

        let normalized = trimmed.replacingOccurrences(of: "\r\n", with: "\n")
        let titlePrefix = "TITLE:"
        if normalized.uppercased().hasPrefix(titlePrefix),
           let splitIndex = normalized.firstIndex(of: "\n") {
            let title = normalized[..<splitIndex]
                .replacingOccurrences(of: titlePrefix, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let bodyStart = normalized.index(after: splitIndex)
            let body = String(normalized[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedArticleResponse(
                title: title.isEmpty ? "Generated Article" : title,
                bodyText: body
            )
        }

        let parts = normalized.components(separatedBy: "\n\n")
        if parts.count >= 2 {
            let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let body = parts.dropFirst().joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedArticleResponse(
                title: title.isEmpty ? "Generated Article" : title,
                bodyText: body
            )
        }

        return ParsedArticleResponse(
            title: "Generated Article",
            bodyText: normalized
        )
    }

    private func extractDeclaredFocusWords(from json: [String: Any]) -> [String] {
        let buckets = [
            json["used_reinforcement_words"],
            json["used_stretch_words"],
            json["target_words"]
        ]

        var seen = Set<String>()
        var words: [String] = []
        for bucket in buckets {
            guard let raw = bucket as? [Any] else { continue }
            for value in raw {
                guard let text = value as? String else { continue }
                let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
                words.append(normalized)
            }
        }
        return words
    }

    private func extractDiscoveredLexemes(from json: [String: Any]) -> [DiscoveredLexemeCandidate] {
        let rawSources: [[Any]] = [
            json["glossary"] as? [Any] ?? [],
            json["discovered_words"] as? [Any] ?? [],
            json["lexical_items"] as? [Any] ?? []
        ]

        var candidates: [DiscoveredLexemeCandidate] = []

        for source in rawSources {
            for item in source {
                guard let dictionary = item as? [String: Any] else { continue }
                guard let lemma = normalizedString(
                    (dictionary["lemma"] as? String) ??
                    (dictionary["word"] as? String) ??
                    (dictionary["term"] as? String)
                ) else { continue }

                let definition = normalizedString(
                    (dictionary["definition"] as? String) ??
                    (dictionary["meaning"] as? String) ??
                    (dictionary["gloss"] as? String)
                )

                let partOfSpeech = normalizedString(
                    (dictionary["part_of_speech"] as? String) ??
                    (dictionary["partOfSpeech"] as? String) ??
                    (dictionary["pos"] as? String)
                )

                let ipa = normalizedString(dictionary["ipa"] as? String)

                let synonyms = stringArray(from: dictionary["synonyms"] ?? dictionary["synonym"])
                let examples = stringArray(
                    from: dictionary["examples"] ??
                        dictionary["example_sentences"] ??
                        dictionary["sentences"]
                )

                let confidence = numericValue(dictionary["confidence"])

                candidates.append(
                    DiscoveredLexemeCandidate(
                        lemma: lemma,
                        definition: definition,
                        partOfSpeech: partOfSpeech,
                        ipa: ipa,
                        synonyms: synonyms,
                        exampleSentences: examples,
                        confidence: confidence
                    )
                )
            }
        }

        return candidates
    }

    private func stringArray(from value: Any?) -> [String] {
        if let array = value as? [String] {
            return array
        }
        if let array = value as? [Any] {
            return array.compactMap { $0 as? String }
        }
        if let scalar = value as? String {
            return scalar
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    private func numericValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private func normalizedString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func ingestDiscoveredLexemes(
        _ candidates: [DiscoveredLexemeCandidate],
        sourceArticleId: String
    ) async throws {
        guard !candidates.isEmpty else { return }

        try await MainActor.run {
            let modelContext = ModelContext(Persistence.sharedModelContainer)
            let activeUser = UserProfile.resolveActiveProfile(modelContext: modelContext)
            _ = try discoveredLexemeIngestionService.ingest(
                candidates: candidates,
                sourceArticleId: sourceArticleId,
                modelContext: modelContext,
                userId: activeUser.userId
            )
        }
    }
}

fileprivate struct Template: Codable {
    let category: String
    let prompt_structure: String
}

private struct ConstructedPrompt {
    let body: String
    let centerRank: Int?
}

private struct ParsedArticleResponse {
    let title: String
    let bodyText: String
    let discoveredLexemes: [DiscoveredLexemeCandidate]
    let declaredFocusWords: [String]

    init(
        title: String,
        bodyText: String,
        discoveredLexemes: [DiscoveredLexemeCandidate] = [],
        declaredFocusWords: [String] = []
    ) {
        self.title = title
        self.bodyText = bodyText
        self.discoveredLexemes = discoveredLexemes
        self.declaredFocusWords = declaredFocusWords
    }
}
