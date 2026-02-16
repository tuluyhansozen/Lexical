import Foundation
import SwiftData

/// Resolves lemmas to vocabulary states via user-centric lexical state.
@MainActor
public final class LemmaResolver {

    private let modelContext: ModelContext

    /// Cache for lemma lookups to avoid repeated queries.
    private var stateCache: [String: VocabularyState] = [:]

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Resolve a batch of lemmas to their vocabulary states.
    /// - Parameter lemmas: Set of lemmas to look up
    /// - Returns: Dictionary mapping lemma to VocabularyState
    public func resolveStates(for lemmas: Set<String>) -> [String: VocabularyState] {
        var results: [String: VocabularyState] = [:]

        var uncachedLemmas: Set<String> = []
        for lemma in lemmas {
            if let cached = stateCache[lemma] {
                results[lemma] = cached
            } else {
                uncachedLemmas.insert(lemma)
            }
        }

        guard !uncachedLemmas.isEmpty else {
            return results
        }

        do {
            let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
            let activeUserId = activeProfile.userId
            let ignored = Set(activeProfile.ignoredWords.map { $0.lowercased() })
            let stateDescriptor = FetchDescriptor<UserWordState>(
                predicate: #Predicate { state in
                    state.userId == activeUserId
                }
            )
            let states = try modelContext.fetch(stateDescriptor)

            var stateByLemma: [String: UserWordState] = [:]
            stateByLemma.reserveCapacity(states.count)
            for state in states {
                stateByLemma[state.lemma] = state
            }

            for lemma in uncachedLemmas {
                let normalized = lemma.lowercased()
                let resolved: VocabularyState

                if ignored.contains(normalized) {
                    resolved = .known
                } else if let state = stateByLemma[normalized] {
                    resolved = mapToState(state)
                } else {
                    resolved = .new
                }

                results[normalized] = resolved
                stateCache[normalized] = resolved
            }
        } catch {
            for lemma in uncachedLemmas {
                results[lemma] = .unknown
            }
        }

        return results
    }

    private func mapToState(_ state: UserWordState) -> VocabularyState {
        switch state.status {
        case .known, .ignored:
            return .known
        case .learning:
            return .learning
        case .new:
            return .new
        }
    }

    /// Clear the cache (call when vocabulary updates).
    public func invalidateCache() {
        stateCache.removeAll()
    }

    /// Invalidate a specific lemma (e.g., after capture).
    public func invalidate(lemma: String) {
        stateCache.removeValue(forKey: lemma.lowercased())
    }
}
