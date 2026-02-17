import Foundation
import SwiftData
import XCTest
@testable import LexicalCore

@MainActor
final class ArticleGeneratorQualityGateTests: XCTestCase {
    private let activeUserDefaultsKey = UserProfile.activeUserDefaultsKey

    override func tearDown() {
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.removeObject(forKey: activeUserDefaultsKey)
        super.tearDown()
    }

    func testGeneratorRetriesAfterStructuralFailure() async throws {
        let originalContainer = Persistence.sharedModelContainer
        defer { Persistence.sharedModelContainer = originalContainer }

        let container = try makeInMemoryContainer()
        Persistence.sharedModelContainer = container

        let context = ModelContext(container)
        let userId = "quality.retry.structural.\(UUID().uuidString)"
        context.insert(UserProfile(userId: userId))
        try context.save()
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.set(userId, forKey: activeUserDefaultsKey)

        let first = """
        {
          "title": "First Attempt",
          "body_text": "Too short to pass.",
          "target_words": ["insight", "workflow", "trade-off"],
          "glossary": []
        }
        """
        let second = """
        {
          "title": "Second Attempt",
          "body_text": "\(Self.makeValidBody(topic: "workflow habits"))",
          "target_words": ["insight", "workflow", "trade-off"],
          "glossary": []
        }
        """
        let provider = SequencedLLMProvider(responses: [first, second])
        let generator = ArticleGenerator(store: ArticleStore(), llmProvider: provider)

        let article = try await generator.generateArticle(
            profile: InterestProfile(selectedTags: ["Technology"]),
            targetWords: ["insight", "workflow", "trade-off"]
        )

        XCTAssertEqual(article.title, "Second Attempt")
        let structuralRetryCount = await provider.callCount()
        XCTAssertEqual(structuralRetryCount, 2)
        let prompts = await provider.promptHistory()
        XCTAssertTrue(prompts.count >= 2)
        XCTAssertTrue(prompts[1].contains("Retry corrections (must follow all):"))
        XCTAssertTrue(prompts[1].contains("Increase article length above 220 words"))
    }

    func testGeneratorRetriesWhenNoveltySimilarityIsTooHigh() async throws {
        let originalContainer = Persistence.sharedModelContainer
        defer { Persistence.sharedModelContainer = originalContainer }

        let container = try makeInMemoryContainer()
        Persistence.sharedModelContainer = container

        let context = ModelContext(container)
        let userId = "quality.retry.novelty.\(UUID().uuidString)"
        context.insert(UserProfile(userId: userId))
        try context.save()
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.set(userId, forKey: activeUserDefaultsKey)

        let store = ArticleStore()
        try await store.save(
            GeneratedArticle(
                title: "Decision Quality in Teams",
                content: Self.makeValidBody(topic: "decision quality"),
                targetWords: ["insight", "workflow", "trade-off"],
                category: "Business",
                difficultyScore: 0.8
            )
        )

        let duplicate = """
        {
          "title": "Decision Quality in Teams",
          "body_text": "\(Self.makeValidBody(topic: "decision quality"))",
          "target_words": ["insight", "workflow", "trade-off"],
          "glossary": []
        }
        """
        let fresh = """
        {
          "title": "Rethinking Bottlenecks in Team Planning",
          "body_text": "\(Self.makeValidBody(topic: "team planning bottlenecks"))",
          "target_words": ["insight", "workflow", "trade-off"],
          "glossary": []
        }
        """
        let provider = SequencedLLMProvider(responses: [duplicate, fresh])
        let generator = ArticleGenerator(store: store, llmProvider: provider)

        let article = try await generator.generateArticle(
            profile: InterestProfile(selectedTags: ["Business", "Technology"]),
            targetWords: ["insight", "workflow", "trade-off"]
        )

        XCTAssertEqual(article.title, "Rethinking Bottlenecks in Team Planning")
        let noveltyRetryCount = await provider.callCount()
        XCTAssertEqual(noveltyRetryCount, 2)
        let prompts = await provider.promptHistory()
        XCTAssertTrue(prompts[1].contains("Pick a fresher angle and different examples than recent articles."))
    }

    func testGeneratorCapsOverlongOutputToTargetRange() async throws {
        let originalContainer = Persistence.sharedModelContainer
        defer { Persistence.sharedModelContainer = originalContainer }

        let container = try makeInMemoryContainer()
        Persistence.sharedModelContainer = container

        let context = ModelContext(container)
        let userId = "quality.cap.overlong.\(UUID().uuidString)"
        context.insert(UserProfile(userId: userId))
        try context.save()
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.set(userId, forKey: activeUserDefaultsKey)

        let response = """
        {
          "title": "Overlong Output",
          "body_text": "\(Self.makeOverlongBody(topic: "retrieval-first routines"))",
          "target_words": ["insight", "workflow", "trade-off", "retrieval", "context", "practice"],
          "glossary": []
        }
        """
        let provider = SequencedLLMProvider(responses: [response])
        let generator = ArticleGenerator(store: ArticleStore(), llmProvider: provider)

        let article = try await generator.generateArticle(
            profile: InterestProfile(selectedTags: ["Technology"]),
            targetWords: ["insight", "workflow", "trade-off", "retrieval", "context", "practice"]
        )

        let count = article.content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        XCTAssertLessThanOrEqual(count, 440)
        XCTAssertGreaterThanOrEqual(count, 220)
        let requestCount = await provider.callCount()
        XCTAssertEqual(requestCount, 1)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV6.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func makeValidBody(topic: String) -> String {
        let paragraphs = [
            "In this reading, we examine \(topic) through a practical lens for intermediate learners. Each section connects one insight to one concrete action so the argument remains usable in daily routines. The goal is to build durable understanding instead of collecting disconnected tips. This makes the text relevant for real decisions, not only passive recognition.",
            "A strong workflow starts with a narrow question and one explicit trade-off decision. When learners define constraints first, they evaluate options faster and avoid shallow comparisons. This makes new vocabulary easier to recall because every term is tied to consequences. The method also lowers friction because each paragraph answers a specific question.",
            "During the middle sections, the article compares two realistic approaches with clear boundary conditions. One method optimizes speed while the other protects quality under pressure, and both have failure modes. Seeing these contrasts builds transfer because the reader can adapt ideas to new contexts. That transfer is what turns comprehension into flexible fluency.",
            "The closing section converts reflection into action by proposing a one-week experiment. Readers summarize the core claim, test one adjustment, and observe outcomes in a short log. That loop turns reading into behavior and keeps progress steady even on busy days. Practical follow-through is the bridge between short sessions and long-term retention.",
            "A final check-in reinforces retention: explain the core argument from memory, identify one assumption that might fail, and rewrite one sentence using new vocabulary in a different context. This retrieval step sharpens understanding and prepares the learner for future review."
        ]
        return paragraphs.joined(separator: "\\n\\n")
    }

    private static func makeOverlongBody(topic: String) -> String {
        let paragraph = """
        In this reading about \(topic), insight guides workflow decisions while retrieval protects context under pressure. Each section compares one trade-off and one practice so the learner can explain a choice, defend an assumption, and apply the idea in a realistic weekly routine without drifting into vague advice.
        """
        return Array(repeating: paragraph, count: 16).joined(separator: "\\n\\n")
    }
}

private actor SequencedLLMProvider: ArticleLLMProvider {
    private var responses: [String]
    private var prompts: [String] = []

    init(responses: [String]) {
        self.responses = responses
    }

    func generateContent(prompt: String) async throws -> String {
        prompts.append(prompt)
        if responses.isEmpty {
            return "{}"
        }
        return responses.removeFirst()
    }

    func callCount() -> Int {
        prompts.count
    }

    func promptHistory() -> [String] {
        prompts
    }
}
