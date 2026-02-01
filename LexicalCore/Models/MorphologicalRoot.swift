import Foundation
import SwiftData

/// Represents an etymological root for the morphology matrix
@Model
public final class MorphologicalRoot {
    /// The root string (e.g., "spect", "chron")
    @Attribute(.unique) public var root: String
    
    /// Meaning of the root
    public var meaning: String
    
    /// Origin language (Latin, Greek, etc.)
    public var origin: String
    
    /// Example words derived from this root
    public var exampleWords: [String]
    
    /// Vocabulary items connected to this root
    @Relationship
    public var vocabularyItems: [VocabularyItem]
    
    public init(root: String, meaning: String, origin: String = "Latin", exampleWords: [String] = []) {
        self.root = root.lowercased()
        self.meaning = meaning
        self.origin = origin
        self.exampleWords = exampleWords
        self.vocabularyItems = []
    }
}
