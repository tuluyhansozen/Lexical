import Foundation

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

    public init(
        store: ArticleStore,
        evaluator: ArticleConstraintsEvaluator = .init(),
        llmProvider: ArticleLLMProvider = MockLLMProvider(),
        promptBuilder: AdaptivePromptBuilder = .init()
    ) {
        self.store = store
        self.evaluator = evaluator
        self.llmProvider = llmProvider
        self.promptBuilder = promptBuilder
    }

    /// Generates a new article personalized to the user.
    public func generateArticle(
        profile: InterestProfile,
        targetWords: [String],
        adaptiveContext: AdaptivePromptContext? = nil,
        knownWords: [String] = []
    ) async throws -> GeneratedArticle {
        _ = knownWords
        let theme = selectTheme(from: profile)
        let constructedPrompt = constructPrompt(
            theme: theme,
            targets: targetWords,
            adaptiveContext: adaptiveContext
        )
        let rawResponse = try await llmProvider.generateContent(prompt: constructedPrompt.body)
        let (title, content) = parseResponse(rawResponse)

        let wordCount = content.split(separator: " ").count
        let containedTargets = targetWords.filter { content.localizedCaseInsensitiveContains($0) }
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
        adaptiveContext: AdaptivePromptContext?
    ) -> ConstructedPrompt {
        let templatePrompt = templatePrompt(theme: theme, targets: targets)

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

    private func templatePrompt(theme: String, targets: [String]) -> String {
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
                    + "\nOutput JSON with keys: title, body_text."
            }
        }

        return """
        Write a short article about \(theme).
        Target constraints:
        - Include these words explicitly: \(targets.joined(separator: ", "))
        - Length: 150-300 words.
        - Tone: Engaging and educational.
        - Output JSON with keys "title" and "body_text".
        """
    }

    private func parseResponse(_ response: String) -> (String, String) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let title = json["title"] as? String {
                let body = (json["body_text"] as? String) ?? (json["body"] as? String) ?? ""
                if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return (title, body)
                }
            }
            if let body = json["content"] as? String {
                return ("Generated Article", body)
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
            return (title.isEmpty ? "Generated Article" : title, body)
        }

        let parts = normalized.components(separatedBy: "\n\n")
        if parts.count >= 2 {
            let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let body = parts.dropFirst().joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (title.isEmpty ? "Generated Article" : title, body)
        }

        return ("Generated Article", normalized)
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
