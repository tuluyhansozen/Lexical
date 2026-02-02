import Foundation
import SwiftData
import LexicalCore

/// VocabularySeeder - Batch imports vocabulary from seed_data.json into SwiftData
///
/// This seeder performs idempotent, versioned seeding of vocabulary data.
/// Uses the #Unique macro on lemma field for deduplication.
@MainActor
public final class VocabularySeeder: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = VocabularySeeder()
    
    // MARK: - Published State
    @Published public private(set) var isSeeding: Bool = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var wordCount: Int = 0
    @Published public private(set) var rootCount: Int = 0
    @Published public private(set) var lastError: String?
    
    // MARK: - Version Control
    private let seedVersionKey = "com.lexical.seedData.version"
    
    private init() {}
    
    // MARK: - Seed Data Structures
    
    struct SeedFile: Codable {
        let version: Int
        let generated_at: String
        let total_entries: Int
        let coverage: Coverage
        let entries: [SeedEntry]
        
        struct Coverage: Codable {
            let ipa: Double
            let definitions: Double
            let roots: Double
            let synonyms: Double?
            let unique_roots: Int?
        }
    }
    
    struct SeedEntry: Codable {
        let id: Int
        let lemma: String
        let rank: Int
        let cefr: String
        let pos: String
        let ipa: String?
        let definition: String?
        let synonyms: [String]?
        let collocations: [Int] // IDs of related words
        let fsrs: FSRSData
        let sentences: [Sentence]
        
        struct FSRSData: Codable {
            let difficulty: Double
            let stability: Double
            let retrievability: Double
        }
        
        struct Sentence: Codable {
            let text: String
            let cloze_index: Int
        }
    }
    
    // MARK: - Public API
    
    /// Seeds the database with vocabulary data from seed_data.json
    /// - Parameter container: The ModelContainer to seed into
    /// - Returns: True if seeding was performed, false if already up-to-date
    @discardableResult
    public func seed(modelContainer: ModelContainer) async -> Bool {
        guard !isSeeding else { return false }
        
        isSeeding = true
        progress = 0.0
        lastError = nil
        
        defer { isSeeding = false }
        
        do {
            // Load seed file
            guard let seedData = try loadSeedData() else {
                lastError = "Failed to load seed_data.json"
                return false
            }
            
            // Check version
            let currentVersion = UserDefaults.standard.integer(forKey: seedVersionKey)
            guard seedData.version > currentVersion else {
                print("✅ Seed data already up-to-date (v\(currentVersion))")
                await updateCounts(container: modelContainer)
                return false
            }
            
            print("📦 Seeding vocabulary v\(seedData.version) (\(seedData.total_entries) entries)...")
            
            // Perform seeding
            try await performSeed(data: seedData, container: modelContainer)
            
            // Update version
            UserDefaults.standard.set(seedData.version, forKey: seedVersionKey)
            
            // Update counts
            await updateCounts(container: modelContainer)
            
            print("✅ Seeding complete: \(wordCount) words, Matrix Graph built.")
            return true
            
        } catch {
            lastError = error.localizedDescription
            print("❌ Seeding failed: \(error)")
            return false
        }
    }
    
    /// Forces a re-seed by resetting version
    public func resetSeedVersion() {
        UserDefaults.standard.removeObject(forKey: seedVersionKey)
    }
    
    // MARK: - Private Methods
    
    private func loadSeedData() throws -> SeedFile? {
        // Try bundle resources - Bundle.module is used for SwiftPM target resources
        guard let url = Bundle.module.url(forResource: "seed_data", withExtension: "json") else {
            print("⚠️ seed_data.json not found in bundle")
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(SeedFile.self, from: data)
    }
    
    private func performSeed(data: SeedFile, container: ModelContainer) async throws {
        let context = ModelContext(container)
        
        // Pass 1: Create all items
        print("   Phase 1: Creating Nodes...")
        var idToItem: [Int: VocabularyItem] = [:]
        
        let totalEntries = Double(data.entries.count)
        
        // Batch insertion
        for (index, entry) in data.entries.enumerated() {
            // Check if lemma exists? For now assume clean wipe or overwrite check
            // Note: If using deduplication, we should query. 
            // Since we are pivoting model, let's assume valid state.
            
            let vocabItem = VocabularyItem(
                lemma: entry.lemma,
                originalWord: entry.lemma,
                contextSentence: entry.sentences.first?.text ?? "",
                definition: entry.definition
            )
            
            // Apply FSRS initial values
            vocabItem.difficulty = entry.fsrs.difficulty
            vocabItem.stability = entry.fsrs.stability
            vocabItem.retrievability = entry.fsrs.retrievability
            
            context.insert(vocabItem)
            idToItem[entry.id] = vocabItem
            
            progress = (Double(index) / totalEntries) * 0.5 // First 50%
            
            if index % 500 == 0 { try context.save() }
        }
        try context.save()
        
        // Pass 2: Link Collocations
        print("   Phase 2: Linking Edges (Matrix)...")
        
        for (index, entry) in data.entries.enumerated() {
            guard let item = idToItem[entry.id] else { continue }
            
            let links = entry.collocations
            for targetId in links {
                if let targetItem = idToItem[targetId] {
                    // Add edge
                    item.collocations.append(targetItem)
                }
            }
            
            progress = 0.5 + ((Double(index) / totalEntries) * 0.5) // Last 50%
            
            if index % 100 == 0 { try context.save() }
        }
        
        // Final save
        try context.save()
        progress = 1.0
    }
    
    private func updateCounts(container: ModelContainer) async {
        let context = ModelContext(container)
        let wordDescriptor = FetchDescriptor<VocabularyItem>()
        wordCount = (try? context.fetchCount(wordDescriptor)) ?? 0
        // No root count anymore
        rootCount = 0 
    }
}
