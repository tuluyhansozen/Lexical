import Foundation
import SwiftData
import SwiftUI
import LexicalCore

/// Manages the active review session queue and Brain Boost logic
@MainActor
class SessionManager: ObservableObject {
    @Published var queue: [VocabularyItem] = []
    @Published var currentIndex: Int = 0
    @Published var isSessionComplete: Bool = false
    
    private let modelContext: ModelContext
    private let fsrsEngine: FSRSV4Engine
    
    // Track streaks for Brain Boost (consecutive successes in this session)
    @Published var sessionStreaks: [PersistentIdentifier: Int] = [:]
    
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
            
            // Filter: Allow New items (reviewCount == 0) and Reviews
            let dueItems = allItems.filter { item in
                item.reviewCount >= 0 // Include ALL items for testing 
                // && (item.nextReviewDate ?? Date()) <= Date() // Re-enable real scheduling later
            }.sorted { ($0.nextReviewDate ?? Date()) < ($1.nextReviewDate ?? Date()) }
            
            self.queue = dueItems
            self.currentIndex = 0
            // self.sessionStreaks = [:] // Reset streaks
            self.isSessionComplete = queue.isEmpty
            print("🧠 Session started with \(queue.count) items")
            
        } catch {
            print("Failed to fetch session items: \(error)")
        }
    }
    
    /// Current active card
    var currentCard: VocabularyItem? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }
    
    func submitGrade(_ grade: Int) {
        guard let card = currentCard else { return }
        let cardId = card.persistentModelID 
        
        Task {
            // 1. Calculate new FSRS state
            let newState = await fsrsEngine.nextState(
                currentStability: card.stability,
                currentDifficulty: card.difficulty,
                recalled: grade >= 3, // 3 and 4 are "recalled" for FSRS math
                grade: grade,
                daysElapsed: max(0, Date().timeIntervalSince(card.lastReviewedAt ?? card.createdAt) / 86400)
            )
            
            // 2. ALWAYS Log the attempt (Universal Logging)
            let log = ReviewLog(
                vocabularyItem: card,
                grade: grade,
                duration: 0.0,
                stabilityAfter: newState.stability,
                difficultyAfter: newState.difficulty
            )
            modelContext.insert(log)
            print("📝 Logged review for '\(card.lemma)': Grade \(grade)")
            
            // 3. Brain Boost Logic (Session Flow)
            if grade < 3 {
                // FAIL/HARD (1 or 2)
                print("🧠 Brain Boost: Re-queueing '\(card.lemma)' (Grade \(grade))")
                sessionStreaks[cardId] = 0
                reinsertCurrentCard(offset: 3)
                
            } else if grade == 3 {
                // GOOD (3)
                let currentStreak = (sessionStreaks[cardId] ?? 0) + 1
                sessionStreaks[cardId] = currentStreak
                
                if currentStreak < 2 {
                    print("🧠 Good! Streak \(currentStreak)/2. Re-queueing '\(card.lemma)'")
                    reinsertCurrentCard(offset: 5)
                } else {
                    print("✅ Graduated '\(card.lemma)'")
                    updateCardState(card, newState: newState)
                    advanceQueue()
                }
                
            } else {
                // EASY (4)
                print("✅ Graduated '\(card.lemma)' (Easy)")
                updateCardState(card, newState: newState)
                advanceQueue()
            }
        }
    }
    
    /// Update the card with final FSRS state/date after graduation
    private func updateCardState(_ card: VocabularyItem, newState: FSRSV4Engine.FSRSState) {
        var stability = newState.stability
        
        // Morphology Stability Boost
        // If the user already knows other words with this root, learning this one should be faster (higher stability)
        if let root = card.root {
            let masteredSiblings = root.vocabularyItems.filter { 
                $0.persistentModelID != card.persistentModelID && $0.learningState == .mastered 
            }
            
            if !masteredSiblings.isEmpty {
                print("🚀 Morphology Boost! '\(card.lemma)' shares root '\(root.root)' with \(masteredSiblings.count) known words.")
                stability *= 1.5 // 50% boost
            }
        }
        
        card.stability = stability
        card.difficulty = newState.difficulty
        card.retrievability = newState.retrievability
        card.lastReviewedAt = Date()
        card.reviewCount += 1
        
        Task {
            let intervalDays = await fsrsEngine.nextInterval(
                stability: stability,
                requestRetention: 0.9
            )
            card.nextReviewDate = Date().addingTimeInterval(intervalDays * 86400)
        }
    }
    
    /// Move the current card to a later position in the session (Brain Boost)
    private func reinsertCurrentCard(offset: Int) {
        guard currentIndex < queue.count else { return }
        let card = queue[currentIndex]
        
        // Remove and Insert logic
        queue.remove(at: currentIndex)
        
        // Insert at new position
        let newIndex = min(currentIndex + offset, queue.count)
        queue.insert(card, at: newIndex)
    }
    
    /// Advance to the next card in the queue
    private func advanceQueue() {
        if currentIndex < queue.count {
            queue.remove(at: currentIndex)
        }
        
        if queue.isEmpty {
            isSessionComplete = true
        }
        
        currentIndex = 0
    }
}
