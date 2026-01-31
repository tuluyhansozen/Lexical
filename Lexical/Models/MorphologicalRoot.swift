import Foundation
import SwiftData

/// Represents an etymological root for the morphology matrix
@Model
final class MorphologicalRoot {
    /// The root string (e.g., "spect", "chron")
    @Attribute(.unique) var root: String
    
    /// Meaning of the root
    var meaning: String
    
    /// Origin language (Latin, Greek, etc.)
    var origin: String
    
    /// Example words derived from this root
    var exampleWords: [String]
    
    /// Vocabulary items connected to this root
    @Relationship
    var vocabularyItems: [VocabularyItem]
    
    init(root: String, meaning: String, origin: String = "Latin", exampleWords: [String] = []) {
        self.root = root.lowercased()
        self.meaning = meaning
        self.origin = origin
        self.exampleWords = exampleWords
        self.vocabularyItems = []
    }
}
