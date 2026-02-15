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

        let topic = Self.extractTopic(from: prompt)
        let targets = Self.extractWordList(marker: "Include these words explicitly:", from: prompt)
        let reinforcement = Self.extractWordList(marker: "Reinforcement words (must be present):", from: prompt)
        let stretch = Self.extractWordList(marker: "Stretch words (must be present):", from: prompt)
        let focusWords = Self.uniqueOrderedWords(from: targets + reinforcement + stretch)

        let body = Self.buildLongFormBody(
            topic: topic,
            focusWords: focusWords,
            targetWordCount: 500
        )
        let title = "Deep Dive: \(topic)"
        let payload: [String: Any] = [
            "title": title,
            "body_text": body,
            "used_reinforcement_words": reinforcement,
            "used_stretch_words": stretch,
            "target_words": targets,
            "glossary": []
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            return json
        }

        return """
        TITLE: \(title)

        \(body)
        """
    }

    private static func extractTopic(from prompt: String) -> String {
        let lines = prompt.components(separatedBy: .newlines)
        if let topicLine = lines.first(where: { $0.localizedCaseInsensitiveContains("Topic focus:") }) {
            let value = topicLine
                .replacingOccurrences(of: "Topic focus:", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }

        for line in lines {
            guard let aboutRange = line.range(of: "about ", options: .caseInsensitive) else { continue }
            let candidate = line[aboutRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            if !candidate.isEmpty {
                return candidate
            }
        }

        return "Technology"
    }

    private static func extractWordList(marker: String, from prompt: String) -> [String] {
        let lines = prompt.components(separatedBy: .newlines)
        guard let line = lines.first(where: { $0.localizedCaseInsensitiveContains(marker) }) else {
            return []
        }

        guard let markerRange = line.range(of: marker, options: .caseInsensitive) else {
            return []
        }

        let remainder = line[markerRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if remainder.lowercased() == "none" {
            return []
        }

        return remainder
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && $0 != "none" }
    }

    private static func uniqueOrderedWords(from words: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for word in words {
            let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            ordered.append(normalized)
        }
        return ordered
    }

    private static func buildLongFormBody(
        topic: String,
        focusWords: [String],
        targetWordCount: Int
    ) -> String {
        let usableFocusWords = focusWords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.range(of: "^[a-z][a-z-]*$", options: .regularExpression) != nil }
        let focusDrills = usableFocusWords.prefix(8).map { lemma in
            "Notice how \(lemma) is used in a concrete sentence so the meaning stays attached to context rather than memorized in isolation."
        }.joined(separator: " ")
        let focusSentence = usableFocusWords.isEmpty
            ? "As you read, track how ideas connect across examples and summaries."
            : "Key learning words in this article are \(usableFocusWords.joined(separator: ", ")). \(focusDrills)"

        let intro = """
        The most effective way to improve fluency in \(topic) is to combine deep reading with deliberate retrieval. Instead of rushing through short fragments, spend time with one coherent argument from start to finish. A long-form article gives your brain enough context to connect cause and effect, compare viewpoints, and notice subtle transitions in tone. \(focusSentence) By the end of this piece, you should be able to explain the main idea in your own words and reuse the new vocabulary in a fresh example.
        """

        let reusableParagraphs = [
            """
            A useful reading routine starts before the first paragraph. Set a clear question for the session, such as what problem the author is trying to solve, what trade-offs are discussed, and which actions are realistic for a learner to apply immediately. This small pre-reading step changes attention quality. You stop scanning for random facts and start following structure. When your attention follows structure, memory improves because every sentence has a role: introducing a claim, supporting it with evidence, or clarifying a limitation.
            """,
            """
            In practical terms, comprehension improves when examples are specific and emotionally neutral. If every paragraph contains dramatic language, the text feels exciting but difficult to retain. Strong educational writing balances narrative energy with stable explanations. A clear sequence works best: define a concept, provide one concrete example, then contrast it with a near miss. That contrast teaches boundaries. Learners who understand boundaries are less likely to misuse vocabulary, because they know when a term fits and when another choice is more precise.
            """,
            """
            Another high-leverage habit is paragraph summarization. After each section, pause for ten seconds and produce one sentence from memory. Do not look back while summarizing. This tiny retrieval attempt surfaces uncertainty quickly. If the summary is vague, you revisit only the unclear lines instead of rereading the whole page. Over multiple sessions, this approach reduces passive repetition and increases active reconstruction. Active reconstruction is slower in the moment, but it builds durable understanding that transfers into conversation and writing.
            """,
            """
            Vocabulary growth is strongest when words appear in meaningful clusters rather than isolated lists. In a focused article, related terms recur under slightly different conditions: explanation, comparison, and application. That repetition with variation helps your mind build flexible representations. A term first seen in a descriptive sentence later appears in a problem-solving sentence, then in a reflective sentence. The form stays familiar while the function shifts. This is exactly the kind of signal retrieval systems can schedule effectively over the next days.
            """,
            """
            For intermediate learners, reading speed should not be maximized at the expense of reasoning depth. A better metric is decision quality after reading. Can you identify the strongest argument? Can you name one assumption the author depends on? Can you propose one alternative interpretation? These questions force the text to become actionable. Actionable comprehension supports long-term retention because your brain stores not only words, but also decision patterns. Decision patterns are easier to recall later than disconnected definitions.
            """,
            """
            Interest alignment also matters. When a topic matches your curiosity, attention sustains itself with less friction. However, interest alone is not enough. The article still needs coherent progression and clear linguistic scaffolding. Good scaffolding includes explicit transitions, constrained sentence length, and concrete nouns that anchor abstract ideas. With those supports, readers can spend cognitive energy on meaning instead of decoding. The result is a more stable memory trace and higher confidence when re-encountering the same vocabulary in new materials.
            """,
            """
            A strong post-reading step is short production. Write three sentences: one summary, one disagreement, and one transfer statement about how you would apply the idea this week. This pattern creates three memory pathways for the same content. The summary pathway captures structure, the disagreement pathway captures nuance, and the transfer pathway captures utility. If one pathway weakens, another can still trigger recall. This redundancy is especially useful when study sessions are brief and spread across busy days.
            """,
            """
            Finally, treat uncertainty as useful data. When a sentence feels difficult, mark it and continue instead of stopping for every unknown detail. After finishing the section, return to marked lines with a narrower question. This keeps momentum while preserving precision. Over time, your tolerance for ambiguity increases, which is a core skill for real-world reading. Fluency is not perfect certainty at every line; it is the ability to maintain direction, resolve ambiguity efficiently, and keep building understanding across longer texts.
            """
        ]

        var paragraphs: [String] = [intro]
        var nextIndex = 0
        while wordCount(in: paragraphs.joined(separator: " ")) < max(420, targetWordCount - 70) {
            paragraphs.append(reusableParagraphs[nextIndex % reusableParagraphs.count])
            nextIndex += 1
        }

        let closing = """
        In summary, long-form reading works because it blends context, repetition, and retrieval into a single experience. Stay with one article long enough to see how ideas evolve, then convert what you read into a brief output. That final output closes the learning loop: you moved from input to understanding to expression. If you repeat this cycle consistently, vocabulary becomes usable knowledge, not just recognition. The compounding effect is subtle day to day, but unmistakable across a month of focused sessions.
        """
        paragraphs.append(closing)

        return paragraphs.joined(separator: "\n\n")
    }

    private static func wordCount(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
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
    private static let targetReadMinutesRange = 4...5
    private static let targetWordRange = 450...550

    private let store: ArticleStore
    private let evaluator: ArticleConstraintsEvaluator
    private let llmProvider: ArticleLLMProvider
    private let promptBuilder: AdaptivePromptBuilder
    private let promptPlanner: ArticlePromptPlanner
    private let discoveredLexemeIngestionService: DiscoveredLexemeIngestionService

    public init(
        store: ArticleStore,
        evaluator: ArticleConstraintsEvaluator = .init(),
        llmProvider: ArticleLLMProvider = MockLLMProvider(),
        promptBuilder: AdaptivePromptBuilder = .init(),
        promptPlanner: ArticlePromptPlanner = .init(),
        discoveredLexemeIngestionService: DiscoveredLexemeIngestionService = .init()
    ) {
        self.store = store
        self.evaluator = evaluator
        self.llmProvider = llmProvider
        self.promptBuilder = promptBuilder
        self.promptPlanner = promptPlanner
        self.discoveredLexemeIngestionService = discoveredLexemeIngestionService
    }

    /// Generates a new article personalized to the user.
    public func generateArticle(
        profile: InterestProfile,
        targetWords: [String],
        reinforcementWords: [String] = [],
        stretchWords: [String] = [],
        adaptiveContext: AdaptivePromptContext? = nil,
        knownWords: [String] = [],
        userId: String? = nil,
        articleStylePreference: String? = nil
    ) async throws -> GeneratedArticle {
        _ = knownWords
        let recentArticles = await store.loadAll()
        let plan = promptPlanner.buildPlan(
            profile: profile,
            recentArticles: recentArticles,
            targetWords: targetWords,
            userId: userId
        )
        let constructedPrompt = constructPrompt(
            plan: plan,
            targets: targetWords,
            reinforcementWords: reinforcementWords,
            stretchWords: stretchWords,
            adaptiveContext: adaptiveContext,
            articleStylePreference: articleStylePreference
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
            category: plan.category,
            difficultyScore: validation.score,
            targetRank: constructedPrompt.centerRank
        )

        try await store.save(article)
        promptPlanner.recordUsage(plan: plan, userId: userId)
        try await ingestDiscoveredLexemes(
            parsed.discoveredLexemes,
            sourceArticleId: article.id.uuidString
        )
        return article
    }

    private func constructPrompt(
        plan: ArticlePromptPlan,
        targets: [String],
        reinforcementWords: [String],
        stretchWords: [String],
        adaptiveContext: AdaptivePromptContext?,
        articleStylePreference: String?
    ) -> ConstructedPrompt {
        let templatePrompt = templatePrompt(
            plan: plan,
            targets: targets,
            reinforcementWords: reinforcementWords,
            stretchWords: stretchWords,
            articleStylePreference: articleStylePreference
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
            topic: plan.topic,
            baseTemplate: templatePrompt
        )

        return ConstructedPrompt(
            body: adaptive.body,
            centerRank: adaptive.centerRank
        )
    }

    private func templatePrompt(
        plan: ArticlePromptPlan,
        targets: [String],
        reinforcementWords: [String],
        stretchWords: [String],
        articleStylePreference: String?
    ) -> String {
        let reinforcementText = reinforcementWords.isEmpty ? "none" : reinforcementWords.joined(separator: ", ")
        let stretchText = stretchWords.isEmpty ? "none" : stretchWords.joined(separator: ", ")
        let targetsText = targets.isEmpty ? "none" : targets.joined(separator: ", ")
        let recentTitlesText = plan.recentTitleExclusions.isEmpty
            ? "none"
            : plan.recentTitleExclusions.joined(separator: " | ")
        let recentTopicsText = plan.recentTopicExclusions.isEmpty
            ? "none"
            : plan.recentTopicExclusions.joined(separator: ", ")

        let lengthGuidance = """
        - Reading duration target: \(Self.targetReadMinutesRange.lowerBound)-\(Self.targetReadMinutesRange.upperBound) minutes.
        - Length: \(Self.targetWordRange.lowerBound)-\(Self.targetWordRange.upperBound) words.
        - Structure: 5-7 short paragraphs with clear transitions and concrete examples.
        - Keep the article meaningful, specific, and interesting for intermediate learners.
        """

        let planningGuidance = """
        Topic and angle brief:
        - Primary topic: \(plan.topic)
        - Interest category context: \(plan.category)
        - Angle to use: \(plan.angleName)
        - Angle directive: \(plan.angleDirective)
        - Opening hook to address early: \(plan.openingHook)

        Freshness constraints:
        - Avoid reusing or paraphrasing these recent titles: \(recentTitlesText)
        - Avoid repeating these recent topic anchors: \(recentTopicsText)
        - Use different examples, structure, and framing than recent outputs.
        """

        let qualityGuidance = """
        Content quality constraints:
        - Include one realistic scenario and one explicit counterpoint.
        - End with a practical "what to do this week" takeaway.
        - Keep claims factual and conservative; do not fabricate statistics or named studies.
        - Integrate target words naturally in meaningful context; avoid list-like insertion.
        - Do not output placeholder tokens (e.g., scenario_word_###).
        """
        let styleGuidance = styleGuidanceLine(for: articleStylePreference)

        if let url = Bundle.main.url(forResource: "ArticleTemplateBank", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let bank = try? JSONDecoder().decode([String: [Template]].self, from: data),
           let templates = bank["templates"] {
            let template = templates.first { $0.category.lowercased() == plan.category.lowercased() }
                ?? templates.first { $0.category == "General" }

            if let template {
                return template.prompt_structure
                    .replacingOccurrences(of: "[THEME]", with: plan.topic)
                    .replacingOccurrences(of: "[TOPIC]", with: plan.topic)
                    .replacingOccurrences(of: "[CATEGORY]", with: plan.category)
                    .replacingOccurrences(of: "[TARGETS]", with: targetsText)
                    + """

                    \(planningGuidance)

                    Output STRICT JSON with keys:
                    - title: string
                    - body_text: string
                    - used_reinforcement_words: string[]
                    - used_stretch_words: string[]
                    - target_words: string[]
                    - glossary: array of objects with keys
                      lemma, definition, part_of_speech, ipa, synonyms, examples, confidence

                    Length and quality rules:
                    \(lengthGuidance)
                    \(qualityGuidance)
                    \(styleGuidance)

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
        Write an in-depth article about \(plan.topic) for readers interested in \(plan.category).
        \(planningGuidance)
        Target constraints:
        - Include these words explicitly: \(targetsText)
        - Reinforcement words (must be present): \(reinforcementText)
        - Stretch words (must be present): \(stretchText)
        \(lengthGuidance)
        \(qualityGuidance)
        \(styleGuidance)
        - Tone: Engaging, educational, and concrete.
        - Output strict JSON with keys:
          "title", "body_text", "used_reinforcement_words", "used_stretch_words", "target_words", "glossary".
        - Each glossary item must include:
          "lemma", "definition", "part_of_speech", "ipa", "synonyms", "examples", "confidence".
        """
    }

    private func styleGuidanceLine(for rawPreference: String?) -> String {
        guard let rawPreference = rawPreference?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              let preference = ArticleStylePreference(rawValue: rawPreference) else {
            return "- Style preference: Balanced. Use a clear, practical, and engaging tone."
        }
        return "- Style preference: \(preference.title). \(preference.promptDirective)"
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
