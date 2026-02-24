import Foundation
import SwiftData
import LexicalCore

@MainActor
public class ArticlesViewModel: ObservableObject {
    @Published public var articles: [GeneratedArticle] = []
    @Published public var isGenerating: Bool = false
    
    private let articleStore = ArticleStore()
    private let generator: ArticleGenerator
    
    public init() {
        let provider = ArticleLLMProviderFactory.makeDefaultProvider()
        self.generator = ArticleGenerator(store: articleStore, llmProvider: provider)
        loadArticles()
    }

    /// Preview-only init with pre-loaded articles (bypasses ArticleStore)
    public init(previewArticles: [GeneratedArticle]) {
        let provider = ArticleLLMProviderFactory.makeDefaultProvider()
        self.generator = ArticleGenerator(store: articleStore, llmProvider: provider)
        self.articles = previewArticles
    }
    
    public func loadArticles() {
        Task {
            let loaded = await articleStore.loadAll()
            self.articles = loaded
        }
    }
    
    @discardableResult
    public func generateNewArticle(
        profile: InterestProfile,
        targetWords: [String],
        reinforcementWords: [String] = [],
        stretchWords: [String] = [],
        adaptiveContext: AdaptivePromptContext? = nil,
        userId: String? = nil,
        articleStylePreference: String? = nil
    ) async -> GeneratedArticle? {
        guard !isGenerating else { return nil }
        isGenerating = true

        do {
            let article = try await generator.generateArticle(
                profile: profile,
                targetWords: targetWords,
                reinforcementWords: reinforcementWords,
                stretchWords: stretchWords,
                adaptiveContext: adaptiveContext,
                userId: userId,
                articleStylePreference: articleStylePreference
            )
            self.articles.insert(article, at: 0)
            isGenerating = false
            return article
        } catch {
            print("Failed to generate article: \(error)")
            isGenerating = false
            return nil
        }
    }
}
