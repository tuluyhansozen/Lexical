import Foundation
import SwiftData
import LexicalCore

/// Seeds the vocabulary database on first launch (or when seed version changes).
public final class VocabularySeedService {
    public static let shared = VocabularySeedService()

    private let seedVersion: Int = 1
    private let seedVersionKey = "lexical.seed.version"
    private var isSeeding = false

    private init() {}

    @MainActor
    public func seedIfNeeded(modelContext: ModelContext) {
        guard !isSeeding else { return }
        isSeeding = true
        defer { isSeeding = false }

        let defaults = UserDefaults.standard
        let lastVersion = defaults.integer(forKey: seedVersionKey)
        guard lastVersion < seedVersion else { return }

        guard let url = Bundle.module.url(forResource: "vocab_seed", withExtension: "json") else {
            print("⚠️ VocabularySeedService: Missing vocab_seed.json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(SeedPayload.self, from: data)

            let existingRoots = try modelContext.fetch(FetchDescriptor<MorphologicalRoot>())
            var rootMap: [String: MorphologicalRoot] = Dictionary(
                uniqueKeysWithValues: existingRoots.map { ($0.root.lowercased(), $0) }
            )

            let existingWords = try modelContext.fetch(FetchDescriptor<VocabularyItem>())
            var existingLemmas = Set(existingWords.map { $0.lemma.lowercased() })

            for root in payload.roots {
                let rootKey = root.root.lowercased()
                if rootMap[rootKey] == nil {
                    let newRoot = MorphologicalRoot(
                        root: root.root,
                        meaning: root.meaning,
                        origin: root.origin,
                        exampleWords: root.exampleWords
                    )
                    modelContext.insert(newRoot)
                    rootMap[rootKey] = newRoot
                }
            }

            for word in payload.words {
                let lemma = word.lemma.lowercased()
                guard !existingLemmas.contains(lemma) else { continue }

                let item = VocabularyItem(
                    lemma: lemma,
                    originalWord: word.lemma,
                    contextSentence: word.context,
                    definition: word.definition,
                    root: nil
                )

                if let rootId = word.root?.lowercased(), let root = rootMap[rootId] {
                    item.root = root
                    root.vocabularyItems.append(item)
                }

                modelContext.insert(item)
                existingLemmas.insert(lemma)
            }

            try modelContext.save()
            defaults.set(seedVersion, forKey: seedVersionKey)
            print("✅ VocabularySeedService: Seeded v\(seedVersion)")
        } catch {
            print("❌ VocabularySeedService: Failed to seed - \(error)")
        }
    }
}

private struct SeedPayload: Codable {
    let version: Int
    let roots: [SeedRoot]
    let words: [SeedWord]
}

private struct SeedRoot: Codable {
    let root: String
    let meaning: String
    let origin: String
    let exampleWords: [String]
}

private struct SeedWord: Codable {
    let lemma: String
    let definition: String
    let context: String
    let root: String?
}
