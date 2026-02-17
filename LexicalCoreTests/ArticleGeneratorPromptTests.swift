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

    func testPromptRequestsThreeToFourMinuteArticle() async throws {
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
              "body_text": "Insight and synthesis support reflective study in realistic projects. Learners test one assumption, compare trade-offs, and refine decisions. This routine keeps vocabulary meaningful while improving recall.\\n\\nA practical reading loop starts with one question and one target behavior for the week. Instead of collecting random tips, learners connect each paragraph to a concrete action they can execute today. Reflection after reading turns passive exposure into durable understanding. A clear workflow also keeps context stable when attention drops.\\n\\nWhen people summarize in their own words, they discover uncertainty early and adjust quickly. This lowers frustration because mistakes become signals rather than identity threats. The article then becomes a tool for better decisions, not a static block of information.\\n\\nA second pass through key sections helps learners notice structure: claim, evidence, counterpoint, and takeaway. Seeing this structure repeatedly strengthens transfer into writing and speaking. Vocabulary becomes usable because every term appears in context, purpose, and consequence.\\n\\nBy the end of the session, the reader can explain the central argument, challenge one weak assumption, and propose a better next step. That closes the retrieval loop and makes future review sessions faster, calmer, and more effective.\\n\\nTo sustain progress, learners finish with a one-week experiment and a short reflection log. This turns comprehension into action, surfaces weak assumptions, and creates evidence for the next review session. The same workflow-context loop supports consistent improvement over time.",
              "used_reinforcement_words": ["insight", "workflow"],
              "used_stretch_words": ["synthesis", "context"],
              "target_words": ["insight", "synthesis", "workflow", "context"],
              "glossary": []
            }
            """
        )
        let generator = ArticleGenerator(store: ArticleStore(), llmProvider: provider)
        let profile = InterestProfile(selectedTags: ["Technology"])

        _ = try await generator.generateArticle(
            profile: profile,
            targetWords: ["insight", "synthesis", "workflow", "context"],
            reinforcementWords: ["insight", "workflow"],
            stretchWords: ["synthesis", "context"],
            articleStylePreference: ArticleStylePreference.informative.rawValue
        )

        let capturedPrompt = await provider.lastPromptValue()
        XCTAssertNotNil(capturedPrompt)
        XCTAssertTrue(capturedPrompt?.contains("Reading duration target: 3-4 minutes.") == true)
        XCTAssertTrue(capturedPrompt?.contains("Length: 360-440 words.") == true)
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
