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
            targetWordCount: 400
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
        let focusDrills = usableFocusWords.prefix(6).map { lemma in
            "Notice how \(lemma) appears in a practical sentence so meaning stays attached to context."
        }.joined(separator: " ")
        let focusSentence = usableFocusWords.isEmpty
            ? "As you read, track how ideas connect across examples and summaries."
            : "Key learning words in this article are \(usableFocusWords.joined(separator: ", ")). \(focusDrills)"

        let intro = """
        Improving fluency in \(topic) works best when reading and retrieval reinforce each other. Instead of jumping across disconnected snippets, stay with one coherent argument and test your understanding as you go. \(focusSentence) By the end of this article, you should be able to explain the main claim, name one trade-off, and reuse the new vocabulary in your own sentence.
        """

        let reusableParagraphs = [
            """
            A practical reading routine starts with one question. Ask what problem is being solved and which assumptions matter most. This sharpens attention, because each paragraph is judged for relevance instead of treated as random information. Relevance-first reading improves retention and reduces cognitive noise.
            """,
            """
            Comprehension improves when examples are concrete and comparisons are explicit. A reliable pattern is simple: define a concept, show one realistic example, then compare it with a near miss. This reveals boundaries, and boundaries are what make vocabulary usable in speech and writing.
            """,
            """
            Retrieval is the multiplier. After each section, pause and summarize in one sentence without looking back. If the summary is vague, revisit only the unclear lines. This keeps sessions efficient and turns passive exposure into active reconstruction, which is slower now but more durable later.
            """,
            """
            Vocabulary grows faster when words reappear across functions: description, comparison, and decision-making. Repetition with variation builds flexibility. A word should not only be recognized; it should be used to explain a choice, challenge an idea, or propose a better next step.
            """,
            """
            For intermediate learners, speed should not replace reasoning depth. A better metric is decision quality after reading: can you identify the strongest argument, one hidden assumption, and one alternative interpretation? Actionable understanding is easier to retain than isolated facts.
            """,
            """
            Finish with short production: one summary sentence, one critique sentence, and one transfer sentence about how you would apply the idea this week. This closes the loop from input to expression and makes later review sessions faster and more stable.
            """
        ]

        var paragraphs: [String] = [intro]
        var nextIndex = 0
        while wordCount(in: paragraphs.joined(separator: " ")) < max(260, targetWordCount - 110) {
            paragraphs.append(reusableParagraphs[nextIndex % reusableParagraphs.count])
            nextIndex += 1
        }

        let closing = """
        In short, reading improves when structure, retrieval, and application stay connected. Keep articles cohesive, reflect after each section, and end with a concrete weekly action. Repeating this cycle turns vocabulary into usable fluency.
        """
        paragraphs.append(closing)
        let draft = paragraphs.joined(separator: "\n\n")
        return trimToWordLimit(
            draft,
            maxWords: max(320, targetWordCount + 30)
        )
    }

    private static func wordCount(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private static func trimToWordLimit(_ text: String, maxWords: Int) -> String {
        let tokens = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        guard tokens.count > maxWords else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let clipped = tokens.prefix(maxWords).joined(separator: " ")
        if let punctuationIndex = clipped.lastIndex(where: { ".!?".contains($0) }) {
            let sentenceAligned = String(clipped[...punctuationIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentenceAligned.isEmpty {
                return sentenceAligned
            }
        }
        return clipped.trimmingCharacters(in: .whitespacesAndNewlines)
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
    private static let targetReadMinutesRange = 3...4
    private static let targetWordRange = 360...440
    private static let maxQualityAttempts = 3
    fileprivate static let maxAllowedNoveltySimilarity = 0.84

    private let store: ArticleStore
    private let evaluator: ArticleConstraintsEvaluator
    private let llmProvider: ArticleLLMProvider
    private let promptBuilder: AdaptivePromptBuilder
    private let promptPlanner: ArticlePromptPlanner
    private let noveltyScorer: ArticleNoveltyScorer
    private let discoveredLexemeIngestionService: DiscoveredLexemeIngestionService

    public init(
        store: ArticleStore,
        evaluator: ArticleConstraintsEvaluator = .init(),
        llmProvider: ArticleLLMProvider = MockLLMProvider(),
        promptBuilder: AdaptivePromptBuilder = .init(),
        promptPlanner: ArticlePromptPlanner = .init(),
        noveltyScorer: ArticleNoveltyScorer = .init(),
        discoveredLexemeIngestionService: DiscoveredLexemeIngestionService = .init()
    ) {
        self.store = store
        self.evaluator = evaluator
        self.llmProvider = llmProvider
        self.promptBuilder = promptBuilder
        self.promptPlanner = promptPlanner
        self.noveltyScorer = noveltyScorer
        self.discoveredLexemeIngestionService = discoveredLexemeIngestionService
    }

    /// Generates a new article personalized to the user.
    public func generateArticle(
        profile: InterestProfile,
        targetWords: [String],
        reinforcementWords: [String] = [],
        stretchWords: [String] = [],
        adaptiveContext: AdaptivePromptContext? = nil,
        userId: String? = nil,
        articleStylePreference: String? = nil
    ) async throws -> GeneratedArticle {
        let recentArticles = await store.loadAll()
        let plan = promptPlanner.buildPlan(
            profile: profile,
            recentArticles: recentArticles,
            targetWords: targetWords,
            userId: userId
        )
        var retryHints: [String] = []
        var bestAttempt: QualityGateAttempt?

        for attemptNumber in 1...Self.maxQualityAttempts {
            let constructedPrompt = constructPrompt(
                plan: plan,
                targets: targetWords,
                reinforcementWords: reinforcementWords,
                stretchWords: stretchWords,
                adaptiveContext: adaptiveContext,
                articleStylePreference: articleStylePreference,
                qualityRetryHints: retryHints
            )
            let rawResponse = try await llmProvider.generateContent(prompt: constructedPrompt.body)
            let parsed = parseResponse(rawResponse)
            let title = parsed.title
            let content = enforceWordLimit(parsed.bodyText, maxWords: Self.targetWordRange.upperBound)

            let wordCount = self.wordCount(in: content)
            let responseTargets = parsed.declaredFocusWords.isEmpty ? targetWords : parsed.declaredFocusWords
            let containedTargets = matchedFocusWords(
                candidates: responseTargets,
                in: content
            )
            let validation = evaluator.evaluate(
                text: content,
                newWordCount: containedTargets.count,
                totalWordCount: wordCount
            )
            let noveltySimilarity = noveltySimilarityScore(
                title: title,
                content: content,
                recentArticles: recentArticles
            )
            let qualityIssues = qualityIssueMessages(
                validationIssues: validation.issues,
                noveltySimilarity: noveltySimilarity
            )
            let attempt = QualityGateAttempt(
                parsed: parsed,
                evaluatedBodyText: content,
                containedTargets: containedTargets,
                validation: validation,
                noveltySimilarity: noveltySimilarity,
                centerRank: constructedPrompt.centerRank,
                qualityIssues: qualityIssues
            )
            bestAttempt = bestAttempt.map { pickPreferredAttempt(current: $0, candidate: attempt) } ?? attempt

            if qualityIssues.isEmpty {
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

            if attemptNumber < Self.maxQualityAttempts {
                retryHints = retryDirectives(
                    from: validation.issues,
                    noveltySimilarity: noveltySimilarity
                )
            }
        }

        if let bestAttempt, bestAttempt.hasOnlyNonBlockingIssues {
            let fallbackArticle = GeneratedArticle(
                title: bestAttempt.parsed.title,
                content: bestAttempt.evaluatedBodyText,
                targetWords: bestAttempt.containedTargets,
                category: plan.category,
                difficultyScore: max(0.0, bestAttempt.validation.score - 0.1),
                targetRank: bestAttempt.centerRank
            )
            try await store.save(fallbackArticle)
            promptPlanner.recordUsage(plan: plan, userId: userId)
            try await ingestDiscoveredLexemes(
                bestAttempt.parsed.discoveredLexemes,
                sourceArticleId: fallbackArticle.id.uuidString
            )
            return fallbackArticle
        }

        let issues = bestAttempt?.qualityIssues.joined(separator: " | ") ?? "Unknown quality gate failure"
        throw ArticleGenerationError.qualityGateFailed(issues: issues)
    }

    private func constructPrompt(
        plan: ArticlePromptPlan,
        targets: [String],
        reinforcementWords: [String],
        stretchWords: [String],
        adaptiveContext: AdaptivePromptContext?,
        articleStylePreference: String?,
        qualityRetryHints: [String]
    ) -> ConstructedPrompt {
        let templatePrompt = templatePrompt(
            plan: plan,
            targets: targets,
            reinforcementWords: reinforcementWords,
            stretchWords: stretchWords,
            articleStylePreference: articleStylePreference,
            qualityRetryHints: qualityRetryHints
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
        articleStylePreference: String?,
        qualityRetryHints: [String]
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
        let retryGuidance = retryGuidanceBlock(from: qualityRetryHints)

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
                    \(retryGuidance)

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
        \(retryGuidance)
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

    private func retryGuidanceBlock(from hints: [String]) -> String {
        guard !hints.isEmpty else { return "" }
        let body = hints
            .map { "- \($0)" }
            .joined(separator: "\n")
        return """
        Retry corrections (must follow all):
        \(body)
        - Rewrite from scratch with a fresh structure and examples.
        """
    }

    private func noveltySimilarityScore(
        title: String,
        content: String,
        recentArticles: [GeneratedArticle]
    ) -> Double {
        let candidate = "\(title)\n\(content.prefix(320))"
        let corpus = recentArticles.prefix(12).map { "\($0.title)\n\($0.content.prefix(320))" }
        return noveltyScorer.blendedSimilarity(of: candidate, against: corpus)
    }

    private func qualityIssueMessages(
        validationIssues: [ArticleConstraintsEvaluator.ConstraintViolation],
        noveltySimilarity: Double
    ) -> [String] {
        var issues: [String] = validationIssues.map(description(for:))
        if noveltySimilarity >= Self.maxAllowedNoveltySimilarity {
            issues.append(
                String(
                    format: "Novelty too low (similarity %.2f >= %.2f)",
                    noveltySimilarity,
                    Self.maxAllowedNoveltySimilarity
                )
            )
        }
        return issues
    }

    private func retryDirectives(
        from violations: [ArticleConstraintsEvaluator.ConstraintViolation],
        noveltySimilarity: Double
    ) -> [String] {
        var directives: [String] = []
        for violation in violations {
            switch violation {
            case let .tooShort(_, min):
                directives.append(
                    "Increase article length above \(min) words and keep it within \(Self.targetWordRange.lowerBound)-\(Self.targetWordRange.upperBound) words."
                )
            case let .tooLong(_, max):
                directives.append(
                    "Shorten article length below \(max) words and keep it within \(Self.targetWordRange.lowerBound)-\(Self.targetWordRange.upperBound) words."
                )
            case .vocabularyDensityTooHigh:
                directives.append("Reduce target-word density by using fewer forced repetitions.")
            case .vocabularyDensityTooLow:
                directives.append("Use required target words naturally in meaningful context at least several times.")
            case .unreadable:
                directives.append("Use clear paragraph breaks and readable sentence lengths.")
            case let .insufficientParagraphs(actual, min):
                directives.append("Use at least \(min) paragraphs (current: \(actual)).")
            case let .insufficientSentences(actual, min):
                directives.append("Use at least \(min) complete sentences (current: \(actual)).")
            case .containsPlaceholderToken:
                directives.append("Remove placeholder tokens and keep only natural language.")
            case .possibleFabricatedStatistic:
                directives.append("Avoid unsourced statistics or named-study claims.")
            }
        }
        if noveltySimilarity >= Self.maxAllowedNoveltySimilarity {
            directives.append("Pick a fresher angle and different examples than recent articles.")
        }
        if directives.isEmpty {
            directives.append("Regenerate with stronger structure and concrete examples.")
        }
        return Array(Set(directives)).sorted()
    }

    private func description(for violation: ArticleConstraintsEvaluator.ConstraintViolation) -> String {
        switch violation {
        case let .tooShort(actual, min):
            return "Too short (\(actual) < \(min) words)"
        case let .tooLong(actual, max):
            return "Too long (\(actual) > \(max) words)"
        case let .vocabularyDensityTooHigh(actual, limit):
            return String(format: "Vocabulary density too high (%.3f > %.3f)", actual, limit)
        case let .vocabularyDensityTooLow(actual, limit):
            return String(format: "Vocabulary density too low (%.3f < %.3f)", actual, limit)
        case .unreadable:
            return "Unreadable structure"
        case let .insufficientParagraphs(actual, min):
            return "Insufficient paragraphs (\(actual) < \(min))"
        case let .insufficientSentences(actual, min):
            return "Insufficient sentences (\(actual) < \(min))"
        case .containsPlaceholderToken:
            return "Contains placeholder token"
        case .possibleFabricatedStatistic:
            return "Possible unsourced statistic claim"
        }
    }

    private func pickPreferredAttempt(
        current: QualityGateAttempt,
        candidate: QualityGateAttempt
    ) -> QualityGateAttempt {
        if candidate.qualityIssues.count < current.qualityIssues.count {
            return candidate
        }
        if candidate.qualityIssues.count > current.qualityIssues.count {
            return current
        }
        if candidate.validation.score > current.validation.score {
            return candidate
        }
        if candidate.noveltySimilarity < current.noveltySimilarity {
            return candidate
        }
        return current
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

    private func matchedFocusWords(
        candidates: [String],
        in content: String
    ) -> [String] {
        let tokens = lexicalTokenSet(in: content)
        guard !tokens.isEmpty else { return [] }

        var seen = Set<String>()
        var matches: [String] = []

        for candidate in candidates {
            guard let normalized = normalizedFocusLemma(candidate) else { continue }
            guard tokens.contains(normalized), seen.insert(normalized).inserted else { continue }
            matches.append(normalized)
        }

        return matches
    }

    private func lexicalTokenSet(in text: String) -> Set<String> {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let regex = try? NSRegularExpression(pattern: #"[A-Za-z]+(?:[-'][A-Za-z]+)*"#) else {
            return []
        }

        var tokens = Set<String>()
        for match in regex.matches(in: text, options: [], range: range) {
            guard let tokenRange = Range(match.range, in: text) else { continue }
            tokens.insert(text[tokenRange].lowercased())
        }
        return tokens
    }

    private func normalizedFocusLemma(_ lemma: String) -> String? {
        let normalized = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        guard normalized.range(of: #"^[a-z]+(?:[-'][a-z]+)*$"#, options: .regularExpression) != nil else {
            return nil
        }
        return normalized
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

    private func enforceWordLimit(_ text: String, maxWords: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard wordCount(in: trimmed) > maxWords else {
            return trimmed
        }

        let paragraphs = trimmed
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paragraphs.isEmpty else {
            return trimToWordLimit(trimmed, limit: maxWords)
        }

        var kept: [String] = []
        var totalWords = 0

        for paragraph in paragraphs {
            let paragraphWordCount = wordCount(in: paragraph)
            if kept.isEmpty, paragraphWordCount >= maxWords {
                return trimToWordLimit(paragraph, limit: maxWords)
            }

            if totalWords + paragraphWordCount > maxWords {
                let remaining = maxWords - totalWords
                if remaining >= 24 {
                    kept.append(trimToWordLimit(paragraph, limit: remaining))
                }
                break
            }

            kept.append(paragraph)
            totalWords += paragraphWordCount
        }

        let candidate = kept.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? trimToWordLimit(trimmed, limit: maxWords) : candidate
    }

    private func trimToWordLimit(_ text: String, limit: Int) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        guard words.count > limit else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let clipped = words.prefix(limit).joined(separator: " ")
        if let punctuationIndex = clipped.lastIndex(where: { ".!?".contains($0) }) {
            let sentenceAligned = String(clipped[...punctuationIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if self.wordCount(in: sentenceAligned) >= max(18, limit - 40) {
                return sentenceAligned
            }
        }
        return clipped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func wordCount(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
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

private struct QualityGateAttempt {
    let parsed: ParsedArticleResponse
    let evaluatedBodyText: String
    let containedTargets: [String]
    let validation: ArticleConstraintsEvaluator.ValidationResult
    let noveltySimilarity: Double
    let centerRank: Int?
    let qualityIssues: [String]

    var hasOnlyNonBlockingIssues: Bool {
        let blockingViolationExists = validation.issues.contains { issue in
            switch issue {
            case .vocabularyDensityTooLow, .vocabularyDensityTooHigh:
                return false
            default:
                return true
            }
        }
        let noveltyBlocking = noveltySimilarity >= ArticleGenerator.maxAllowedNoveltySimilarity
        return !blockingViolationExists && !noveltyBlocking
    }
}

public enum ArticleGenerationError: Error, LocalizedError {
    case qualityGateFailed(issues: String)

    public var errorDescription: String? {
        switch self {
        case let .qualityGateFailed(issues):
            return "Article generation failed quality checks: \(issues)"
        }
    }
}
