import AppIntents
import SwiftData
import Foundation
import LexicalCore

// MARK: - App Entity Conformance

struct VocabularyItemEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Vocabulary Item")
    static var defaultQuery = VocabularyItemQuery()
    
    var id: String
    var lemma: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(lemma)")
    }
    
    init(id: String, lemma: String) {
        self.id = id
        self.lemma = lemma
    }
    
    init(from item: VocabularyItem) {
        self.id = item.lemma // Using lemma as ID for simplicity, or UUID
        self.lemma = item.lemma
    }
}

struct VocabularyItemQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [VocabularyItemEntity] {
        let modelContext = ModelContext(Persistence.sharedModelContainer)
        // Fetch logic would go here. For now returning stubs or empty if actual DB fetch is complex without actor
        return []
    }
    
    func suggestedEntities() async throws -> [VocabularyItemEntity] {
        return []
    }
}

// MARK: - Intents

struct StartReviewIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Review Session"
    static var description = IntentDescription("Opens the app and starts a review session.")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Deep link handling would happen in App content
        return .result()
    }
}

struct GetDueCountIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Due Reviews"
    static var description = IntentDescription("Checks how many cards are due for review.")
    
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let modelContext = ModelContext(Persistence.sharedModelContainer)
        let descriptor = FetchDescriptor<VocabularyItem>() // In real app, filter by date
        
        let count: Int
        do {
            let items = try modelContext.fetch(descriptor)
            // Filter logic: nextReviewDate <= now
            count = items.filter { ($0.nextReviewDate ?? Date()) <= Date() }.count
        } catch {
            count = 0
        }
        
        return .result(
            value: count,
            dialog: IntentDialog("You have \(count) cards due for review.")
        )
    }
}

struct GradeCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Grade Card"
    static var description = IntentDescription("Grades a specific card from a widget.")
    
    @Parameter(title: "Lemma")
    var lemma: String?
    
    @Parameter(title: "Grade")
    var grade: Int?
    
    func perform() async throws -> some IntentResult {
        guard let lemma = lemma, let grade = grade else {
            return .result()
        }
        
        let modelContext = ModelContext(Persistence.sharedModelContainer)
        // Fetch Item
        // Apply FSRS (Requires FSRS Engine access unrelated to actor for single shot?)
        // For now, just logging content
        print("Intent graded \(lemma) with \(grade)")
        
        return .result()
    }
}
