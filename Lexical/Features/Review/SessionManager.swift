import Foundation
import SwiftData
import SwiftUI

/// Manages the active review session queue and Brain Boost logic
@MainActor
class SessionManager: ObservableObject {
    @Published var queue: [VocabularyItem] = []
    @Published var currentIndex: Int = 0
    @Published var isSessionComplete: Bool = false
    
    private let modelContext: ModelContext
    private let fsrsEngine: FSRSV4Engine
    
    // Brain Boost Queue: Items that need re-review in this session
    // Stored as (Item, OriginalIndex) pairs if managing complex transitions,
    // but for simplicity, we just inject directly into the main queue.
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.fsrsEngine = FSRSV4Engine()
    }
    
    /// Start a new session with due cards
    func startSession() {
        do {
            // Fetch due items
            // Note: In a real app we'd use a more complex predicate with dates
            // For MVP: Fetch all learning/review items and filter locally
            let descriptor = FetchDescriptor<VocabularyItem>()
            let allItems = try modelContext.fetch(descriptor)
            
            // Filter: (New with reviewCount > 0) OR (NextReview <= Now)
            // Simplifying to just all items for testing flow if count is small
            // Or better:
            let dueItems = allItems.filter { item in
                item.reviewCount > 0 // Only learning items for now
                // && (item.nextReviewDate ?? Date()) <= Date() // Re-enable real scheduling later
            }.sorted { ($0.nextReviewDate ?? Date()) < ($1.nextReviewDate ?? Date()) }
            
            self.queue = dueItems
            self.currentIndex = 0
            self.isSessionComplete = queue.isEmpty
            
        } catch {
            print("Failed to fetch session items: \(error)")
        }
    }
    
    /// Current active card
    var currentCard: VocabularyItem? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }
    
    /// Submit a grade for the current card
    /// - Parameter grade: 1=Again, 2=Hard, 3=Good, 4=Easy
    func submitGrade(_ grade: Int) {
        guard let card = currentCard else { return }
        
        Task {
            // 1. Calculate new FSRS state
            let newState = await fsrsEngine.nextState(
                currentStability: card.stability,
                currentDifficulty: card.difficulty,
                recalled: grade >= 3, // 3 and 4 are "pass"
                grade: grade,
                daysElapsed: max(0, Date().timeIntervalSince(card.lastReviewedAt ?? card.createdAt) / 86400)
            )
            
            // 2. Brain Boost Logic (Review Loop)
            if grade < 3 {
                // FAILED (Again/Hard): Re-insert into queue
                print("🧠 Brain Boost: Re-queueing \(card.lemma)")
                
                // Do NOT update database state yet (keep it pending until passed)
                // Just move it deeper in the session
                reinsertCurrentCard(offset: 3)
                
            } else {
                // PASSED (Good/Easy): Commit to Database
                print("✅ Graduated: \(card.lemma)")
                
                card.stability = newState.stability
                card.difficulty = newState.difficulty
                card.retrievability = newState.retrievability // Reset to 1.0 ideally, or calc
                card.lastReviewedAt = Date()
                card.reviewCount += 1
                
                // Calculate next interval
                let intervalDays = await fsrsEngine.nextInterval(
                    stability: newState.stability,
                    requestRetention: 0.9
                )
                card.nextReviewDate = Date().addingTimeInterval(intervalDays * 86400)
                
                // Create Review Log
                let log = ReviewLog(
                    vocabularyItem: card,
                    grade: grade,
                    duration: 0, // TODO: Track duration
                    stabilityAfter: newState.stability,
                    difficultyAfter: newState.difficulty
                )
                modelContext.insert(log)
                
                // Move to next card
                advanceQueue()
            }
        }
    }
    
    /// Move the current card to a later position in the session (Brain Boost)
    private func reinsertCurrentCard(offset: Int) {
        guard currentIndex < queue.count else { return }
        let card = queue[currentIndex]
        
        // Remove from current pos (conceptually, actually just skipping it and appending copy?)
        // Better: Remove and Insert.
        
        // But we are iterating by index.
        // If we remove current, the next item becomes currentIndex.
        // So we don't increment currentIndex.
        
        queue.remove(at: currentIndex)
        
        // Insert at new position
        let newIndex = min(currentIndex + offset, queue.count)
        queue.insert(card, at: newIndex)
        
        // Note: currentIndex stays same, pointing to the *next* card which slid into this slot
    }
    
    /// Advance to the next card in the queue
    private func advanceQueue() {
        // Since we processed the current card (and saved it), we can remove it from active queue
        // or just increment index.
        // Removing is cleaner for "remaining count"
        if currentIndex < queue.count {
            queue.remove(at: currentIndex)
        }
        
        // If empty, complete
        if queue.isEmpty {
            isSessionComplete = true
        }
        
        // Index stays 0 if we assume head-of-line processing
        // But if we want history, we keep them.
        // Let's go with: Remove processed cards.
        currentIndex = 0
    }
}
