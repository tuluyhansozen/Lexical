import Foundation
import SwiftData

/// Resolves lemmas to vocabulary states via SwiftData lookup
@MainActor
public final class LemmaResolver {
    
    private let modelContext: ModelContext
    
    /// Cache for vocabulary lookups to avoid repeated queries
    private var stateCache: [String: VocabularyState] = [:]
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Resolve a batch of lemmas to their vocabulary states
    /// - Parameter lemmas: Set of lemmas to look up
    /// - Returns: Dictionary mapping lemma to VocabularyState
    public func resolveStates(for lemmas: Set<String>) -> [String: VocabularyState] {
        var results: [String: VocabularyState] = [:]
        
        // Check cache first
        var uncachedLemmas: Set<String> = []
        for lemma in lemmas {
            if let cached = stateCache[lemma] {
                results[lemma] = cached
            } else {
                uncachedLemmas.insert(lemma)
            }
        }
        
        // Early return if all cached
        guard !uncachedLemmas.isEmpty else {
            return results
        }
        
        // Fetch all vocabulary items and filter in memory
        // (SwiftData predicates have limitations with array contains)
        let descriptor = FetchDescriptor<VocabularyItem>()
        
        do {
            let allItems = try modelContext.fetch(descriptor)
            
            // Filter to only items matching our lemmas
            let matchingItems = allItems.filter { uncachedLemmas.contains($0.lemma) }
            
            // Map fetched items to states
            for item in matchingItems {
                let state = mapToState(item)
                results[item.lemma] = state
                stateCache[item.lemma] = state
            }
            
            // Mark unfound lemmas as "new" (not yet in database)
            for lemma in uncachedLemmas {
                if results[lemma] == nil {
                    results[lemma] = .new
                    stateCache[lemma] = .new
                }
            }
            
        } catch {
            // On error, default all to unknown
            for lemma in uncachedLemmas {
                results[lemma] = .unknown
            }
        }
        
        return results
    }
    
    /// Map a VocabularyItem to its display state
    private func mapToState(_ item: VocabularyItem) -> VocabularyState {
        // Check if mastered (stability > threshold)
        if item.stability > 90.0 {
            return .known
        }
        
        // Check if in learning queue
        if item.reviewCount > 0 {
            return .learning
        }
        
        // Default to new
        return .new
    }
    
    /// Clear the cache (call when vocabulary updates)
    public func invalidateCache() {
        stateCache.removeAll()
    }
    
    /// Invalidate a specific lemma (e.g., after capture)
    public func invalidate(lemma: String) {
        stateCache.removeValue(forKey: lemma)
    }
}
