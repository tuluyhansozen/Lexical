import Foundation
import SwiftData
import CryptoKit

/// Service to seed the database with initial vocabulary
public class VocabularySeeder {
    public static let shared = VocabularySeeder()
    private static let seedHashKey = "lexical.seed_data.hash"
    private static let excludedRankRange = 0...200
    
    private init() {}
    
    @MainActor
    public func seed(modelContainer: ModelContainer) async {
        let context = modelContainer.mainContext
        
        do {
            let seedPayload = try loadSeedItems()
            let seedHash = seedPayload.hash
            let rootItems = try loadRootItems()

            let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
            let previousHash = defaults.string(forKey: Self.seedHashKey)

            // Skip fast path only when both canonical corpus and roots are already present.
            var lexemeCountDescriptor = FetchDescriptor<LexemeDefinition>()
            lexemeCountDescriptor.fetchLimit = 1
            let existingLexemeCount = try context.fetchCount(lexemeCountDescriptor)
            var rootCountDescriptor = FetchDescriptor<MorphologicalRoot>()
            rootCountDescriptor.fetchLimit = 1
            let existingRootCount = try context.fetchCount(rootCountDescriptor)
            var excludedRankDescriptor = FetchDescriptor<LexemeDefinition>(
                predicate: #Predicate<LexemeDefinition> { lexeme in
                    (lexeme.rank ?? -1) >= 0 && (lexeme.rank ?? -1) <= 200
                }
            )
            excludedRankDescriptor.fetchLimit = 1
            let existingExcludedRankCount = try context.fetchCount(excludedRankDescriptor)

            if previousHash == seedHash,
               existingLexemeCount > 0,
               existingRootCount > 0,
               existingExcludedRankCount == 0 {
                print("VocabularySeeder: Seed data unchanged. Skipping corpus upsert.")
                return
            }

            if previousHash == nil {
                print("VocabularySeeder: Starting initial seed sync...")
            } else if previousHash == seedHash {
                print("VocabularySeeder: Seed hash unchanged, but missing corpus entities. Repairing...")
            } else {
                print("VocabularySeeder: Seed hash changed. Running non-destructive upsert...")
            }

            let seedItems = seedPayload.items.filter { !Self.shouldExclude(rank: $0.rank) }
            let excludedByRankCount = seedPayload.items.count - seedItems.count
            if excludedByRankCount > 0 {
                print("VocabularySeeder: Excluding \(excludedByRankCount) seed lexemes in rank \(Self.excludedRankRange.lowerBound)...\(Self.excludedRankRange.upperBound).")
            }

            let existingLexemes = try context.fetch(FetchDescriptor<LexemeDefinition>())
            var deletedExcludedLexemes = 0
            for existingLexeme in existingLexemes where Self.shouldExclude(rank: existingLexeme.rank) {
                context.delete(existingLexeme)
                deletedExcludedLexemes += 1
            }

            let filteredExistingLexemes = try context.fetch(FetchDescriptor<LexemeDefinition>())
            var lexemeByLemma: [String: LexemeDefinition] = [:]
            lexemeByLemma.reserveCapacity(filteredExistingLexemes.count)
            for lexeme in filteredExistingLexemes {
                lexemeByLemma[lexeme.lemma] = lexeme
            }

            let existingRoots = try context.fetch(FetchDescriptor<MorphologicalRoot>())
            var rootsById: [Int: MorphologicalRoot] = [:]
            rootsById.reserveCapacity(existingRoots.count)
            for root in existingRoots {
                rootsById[root.rootId] = root
            }

            var lexemeInserted = 0
            var lexemeUpdated = 0
            var rootInserted = 0
            var rootUpdated = 0

            for seed in seedItems {
                let lemma = seed.lemma.lowercased()
                let firstSentence = normalizedString(seed.sentences?.first?.text)
                let definition = normalizedString(seed.definition)

                if let existingLexeme = lexemeByLemma[lemma] {
                    var didUpdate = false
                    if existingLexeme.seedId != seed.id {
                        existingLexeme.seedId = seed.id
                        didUpdate = true
                    }
                    if existingLexeme.rank != seed.rank {
                        existingLexeme.rank = seed.rank
                        didUpdate = true
                    }
                    if existingLexeme.cefrLevel != seed.cefr {
                        existingLexeme.cefrLevel = seed.cefr
                        didUpdate = true
                    }
                    if existingLexeme.partOfSpeech != seed.pos {
                        existingLexeme.partOfSpeech = seed.pos
                        didUpdate = true
                    }
                    if existingLexeme.ipa != seed.ipa {
                        existingLexeme.ipa = seed.ipa
                        didUpdate = true
                    }
                    if existingLexeme.basicMeaning != definition {
                        existingLexeme.basicMeaning = definition
                        didUpdate = true
                    }
                    if existingLexeme.sampleSentence != firstSentence {
                        existingLexeme.sampleSentence = firstSentence
                        didUpdate = true
                    }
                    if didUpdate {
                        existingLexeme.sourceUpdatedAt = Date()
                        lexemeUpdated += 1
                    }
                } else {
                    let lexeme = LexemeDefinition(
                        lemma: lemma,
                        seedId: seed.id,
                        rank: seed.rank,
                        cefrLevel: seed.cefr,
                        partOfSpeech: seed.pos,
                        ipa: seed.ipa,
                        basicMeaning: definition,
                        sampleSentence: firstSentence
                    )
                    context.insert(lexeme)
                    lexemeByLemma[lemma] = lexeme
                    lexemeInserted += 1
                }
            }

            for root in rootItems {
                if let existingRoot = rootsById[root.root_id] {
                    var didUpdate = false
                    if existingRoot.root != root.root {
                        existingRoot.root = root.root
                        didUpdate = true
                    }
                    if existingRoot.basicMeaning != root.basic_meaning {
                        existingRoot.basicMeaning = root.basic_meaning
                        didUpdate = true
                    }
                    if existingRoot.wordIds != root.word_ids {
                        existingRoot.wordIds = root.word_ids
                        didUpdate = true
                    }
                    if didUpdate {
                        rootUpdated += 1
                    }
                    continue
                }

                let rootModel = MorphologicalRoot(
                    rootId: root.root_id,
                    root: root.root,
                    basicMeaning: root.basic_meaning,
                    wordIds: root.word_ids
                )
                context.insert(rootModel)
                rootsById[root.root_id] = rootModel
                rootInserted += 1
            }

            try context.save()
            defaults.set(seedHash, forKey: Self.seedHashKey)

            print(
                "VocabularySeeder: Seed sync complete. " +
                "lexeme(inserted=\(lexemeInserted), updated=\(lexemeUpdated), deletedExcluded=\(deletedExcludedLexemes), total=\(seedItems.count)) " +
                "roots(inserted=\(rootInserted), updated=\(rootUpdated), total=\(rootItems.count))."
            )
        } catch {
            print("VocabularySeeder Error: \(error)")
        }
    }

    private func loadSeedItems() throws -> (items: [SeedItem], hash: String) {
        let mainBundle = Bundle.main
        var candidateBundles: [Bundle] = [mainBundle, Bundle(for: VocabularySeeder.self)]

        if let resourceBundleURL = mainBundle.url(forResource: "Lexical_Lexical", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL) {
            candidateBundles.insert(resourceBundle, at: 0)
        }

        var seedURL: URL? = nil
        for bundle in candidateBundles {
            seedURL = bundle.url(forResource: "seed_data", withExtension: "json", subdirectory: "Seeds") ??
                      bundle.url(forResource: "seed_data", withExtension: "json")
            if seedURL != nil {
                break
            }
        }

        guard let url = seedURL else {
            throw SeedError.missingSeedFile
        }

        let data = try Data(contentsOf: url)
        let hash: String
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            hash = Self.hash(data)
        } else {
            hash = "\(data.count)"
        }
        let decoder = JSONDecoder()

        if let items = try? decoder.decode([SeedItem].self, from: data) {
            return (items, hash)
        }

        let container = try decoder.decode(SeedContainer.self, from: data)
        if let entries = container.entries {
            return (entries, hash)
        }
        if let entries = container.words {
            return (entries, hash)
        }

        throw SeedError.invalidSeedFormat
    }

    private func loadRootItems() throws -> [RootSeedItem] {
        let mainBundle = Bundle.main
        var candidateBundles: [Bundle] = [mainBundle, Bundle(for: VocabularySeeder.self)]

        if let resourceBundleURL = mainBundle.url(forResource: "Lexical_Lexical", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL) {
            candidateBundles.insert(resourceBundle, at: 0)
        }

        var rootsURL: URL? = nil
        for bundle in candidateBundles {
            rootsURL = bundle.url(forResource: "roots", withExtension: "json", subdirectory: "Seeds") ??
                       bundle.url(forResource: "roots", withExtension: "json")
            if rootsURL != nil {
                break
            }
        }

        guard let url = rootsURL else {
            throw SeedError.missingRootsFile
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([RootSeedItem].self, from: data)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    private static func hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func normalizedString(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func shouldExclude(rank: Int?) -> Bool {
        guard let rank else { return false }
        return excludedRankRange.contains(rank)
    }
}

// MARK: - JSON Schema Helpers

fileprivate struct SeedItem: Codable {
    let id: Int?
    let lemma: String
    let rank: Int?
    let cefr: String?
    let pos: String?
    let ipa: String?
    let definition: String?
    let fsrs_initial: FSRSInitial?
    let fsrs: FSRSCompatibility?
    let sentences: [SeedSentence]?
}

fileprivate struct FSRSInitial: Codable {
    let d: Double
    let s: Double
    // r is optional/derived
}

fileprivate struct FSRSCompatibility: Codable {
    let d: Double?
    let s: Double?
    let difficulty: Double?
    let stability: Double?
}

fileprivate struct SeedSentence: Codable {
    let text: String
    // cloze_index ignored for simple seed
}

fileprivate struct SeedContainer: Codable {
    let entries: [SeedItem]?
    let words: [SeedItem]?
}

fileprivate struct RootSeedItem: Codable {
    let root_id: Int
    let root: String
    let basic_meaning: String
    let word_ids: [Int]
}

fileprivate enum SeedError: Error {
    case missingSeedFile
    case missingRootsFile
    case invalidSeedFormat
}
