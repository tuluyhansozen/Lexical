import Foundation
import SwiftData
import XCTest
@testable import LexicalCore

@MainActor
final class ArticleGeneratorPromptTests: XCTestCase {
    private let activeUserDefaultsKey = UserProfile.activeUserDefaultsKey

    override func tearDown() {
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.removeObject(forKey: activeUserDefaultsKey)
        super.tearDown()
    }

    func testPromptRequestsFourToFiveMinuteArticle() async throws {
        let originalContainer = Persistence.sharedModelContainer
        defer { Persistence.sharedModelContainer = originalContainer }

        let container = try makeInMemoryContainer()
        Persistence.sharedModelContainer = container

        let context = ModelContext(container)
        let userId = "prompt.length.\(UUID().uuidString)"
        context.insert(UserProfile(userId: userId))
        try context.save()

        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.set(userId, forKey: activeUserDefaultsKey)

        let provider = PromptCapturingProvider(
            response: """
            {
              "title": "Deep Practice",
              "body_text": "Insight drives synthesis in reflective study routines.",
              "used_reinforcement_words": ["insight"],
              "used_stretch_words": ["synthesis"],
              "target_words": ["insight", "synthesis"],
              "glossary": []
            }
            """
        )
        let generator = ArticleGenerator(store: ArticleStore(), llmProvider: provider)
        let profile = InterestProfile(selectedTags: ["Technology"])

        _ = try await generator.generateArticle(
            profile: profile,
            targetWords: ["insight", "synthesis"],
            reinforcementWords: ["insight"],
            stretchWords: ["synthesis"],
            articleStylePreference: ArticleStylePreference.informative.rawValue
        )

        let capturedPrompt = await provider.lastPromptValue()
        XCTAssertNotNil(capturedPrompt)
        XCTAssertTrue(capturedPrompt?.contains("Reading duration target: 4-5 minutes.") == true)
        XCTAssertTrue(capturedPrompt?.contains("Length: 450-550 words.") == true)
        XCTAssertTrue(capturedPrompt?.contains("Topic and angle brief:") == true)
        XCTAssertTrue(capturedPrompt?.contains("Freshness constraints:") == true)
        XCTAssertTrue(capturedPrompt?.contains("Style preference: Informative.") == true)
        XCTAssertTrue(capturedPrompt?.contains("\"target_words\"") == true)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV6.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

private actor PromptCapturingProvider: ArticleLLMProvider {
    private(set) var lastPrompt: String?
    private let response: String

    init(response: String) {
        self.response = response
    }

    func generateContent(prompt: String) async throws -> String {
        lastPrompt = prompt
        return response
    }

    func lastPromptValue() -> String? {
        lastPrompt
    }
}
