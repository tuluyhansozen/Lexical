import Foundation
import SwiftData

@Model
public final class InterestProfile {
    public var selectedTags: [String] = []
    public var categoryWeights: [String: Double] = [:]
    public var readArticleIDs: [UUID] = []
    public var lastUpdated: Date = Date()
    
    public init(selectedTags: [String] = [], categoryWeights: [String : Double] = [:]) {
        self.selectedTags = selectedTags
        self.categoryWeights = categoryWeights
        self.readArticleIDs = []
        self.lastUpdated = Date()
    }
    
    public func recordRead(articleID: UUID, category: String) {
        if !readArticleIDs.contains(articleID) {
            readArticleIDs.append(articleID)
            // Decay old weights
            for (key, value) in categoryWeights {
                categoryWeights[key] = value * 0.95
            }
            // Boost current category
            categoryWeights[category, default: 0.5] += 0.1
            lastUpdated = Date()
        }
    }
    
    public func addTag(_ tag: String) {
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty && !selectedTags.contains(normalized) {
            selectedTags.append(normalized)
            selectedTags.sort()
            lastUpdated = Date()
        }
    }
    
    public func removeTags(at offsets: IndexSet) {
        selectedTags.remove(atOffsets: offsets)
        lastUpdated = Date()
    }
}
