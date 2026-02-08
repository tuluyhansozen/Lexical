import Foundation

public struct GeneratedArticle: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var content: String
    public var targetWords: [String] // Lemmas targeted
    public var category: String
    public var generatedDate: Date
    public var difficultyScore: Double
    
    public init(id: UUID = UUID(), title: String, content: String, targetWords: [String], category: String, generatedDate: Date = Date(), difficultyScore: Double) {
        self.id = id
        self.title = title
        self.content = content
        self.targetWords = targetWords
        self.category = category
        self.generatedDate = generatedDate
        self.difficultyScore = difficultyScore
    }
}

public actor ArticleStore {
    private let fileManager = FileManager.default
    private let folderName = "GeneratedArticles"
    
    public init() {}
    
    private var directoryURL: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(folderName)
    }
    
    private func createDirectoryIfNeeded() throws {
        guard let url = directoryURL else { return }
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    public func save(_ article: GeneratedArticle) throws {
        try createDirectoryIfNeeded()
        guard let url = directoryURL?.appendingPathComponent("\(article.id.uuidString).json") else { return }
        let data = try JSONEncoder().encode(article)
        try data.write(to: url)
    }
    
    public func loadAll() -> [GeneratedArticle] {
        try? createDirectoryIfNeeded()
        guard let url = directoryURL else { return [] }
        guard let files = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return [] }
        
        var articles: [GeneratedArticle] = []
        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let article = try? JSONDecoder().decode(GeneratedArticle.self, from: data) {
                articles.append(article)
            }
        }
        return articles.sorted(by: { $0.generatedDate > $1.generatedDate })
    }
    
    public func delete(_ id: UUID) {
        guard let url = directoryURL?.appendingPathComponent("\(id.uuidString).json") else { return }
        try? fileManager.removeItem(at: url)
    }
}
