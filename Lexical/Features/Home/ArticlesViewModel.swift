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
    
    public func loadArticles() {
        Task {
            let loaded = await articleStore.loadAll()
            self.articles = loaded
        }
    }
    
    public func generateNewArticle(profile: InterestProfile, targetWords: [String]) {
        guard !isGenerating else { return }
        isGenerating = true
        
        Task {
            do {
                let article = try await generator.generateArticle(profile: profile, targetWords: targetWords)
                self.articles.insert(article, at: 0)
                isGenerating = false
            } catch {
                print("Failed to generate article: \(error)")
                isGenerating = false
            }
        }
    }
}
