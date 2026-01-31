import Foundation
import NaturalLanguage

/// Background actor for tokenizing text and extracting lemmas
actor TokenizationActor {
    
    /// Represents a tokenized word with its lemma and range
    struct TokenizedWord: Sendable {
        let originalWord: String
        let lemma: String
        let range: Range<String.Index>
        let sentenceRange: Range<String.Index>?
    }
    
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger: NLTagger
    
    /// Common stop words to filter out
    private let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "is", "are", "was", "were", "be", "been",
        "being", "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "may", "might", "must", "shall", "can", "this",
        "that", "these", "those", "i", "you", "he", "she", "it", "we", "they",
        "my", "your", "his", "her", "its", "our", "their", "what", "which",
        "who", "whom", "when", "where", "why", "how", "all", "each", "every",
        "both", "few", "more", "most", "other", "some", "such", "no", "nor",
        "not", "only", "own", "same", "so", "than", "too", "very", "just",
        "as", "if", "then", "else", "there", "here", "about", "into", "through",
        "during", "before", "after", "above", "below", "between", "under", "again"
    ]
    
    init() {
        self.tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
    }
    
    /// Tokenize text and extract lemmas
    /// - Parameter text: The input text to tokenize
    /// - Returns: Array of TokenizedWord with lemmas and ranges
    func tokenize(_ text: String) async -> [TokenizedWord] {
        var results: [TokenizedWord] = []
        
        tokenizer.string = text
        tagger.string = text
        
        // Get sentence boundaries for context extraction
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        var sentenceBoundaries: [Range<String.Index>] = []
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentenceBoundaries.append(range)
            return true
        }
        
        // Tokenize words
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).lowercased()
            
            // Skip stop words and short words
            guard word.count > 1, !self.stopWords.contains(word) else {
                return true
            }
            
            // Skip numbers and punctuation-only tokens
            guard word.rangeOfCharacter(from: .letters) != nil else {
                return true
            }
            
            // Get lemma from tagger
            let (lemmaTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma)
            let lemma = lemmaTag?.rawValue.lowercased() ?? word
            
            // Find containing sentence
            let sentenceRange = sentenceBoundaries.first { $0.contains(range.lowerBound) }
            
            results.append(TokenizedWord(
                originalWord: String(text[range]),
                lemma: lemma,
                range: range,
                sentenceRange: sentenceRange
            ))
            
            return true
        }
        
        return results
    }
    
    /// Extract the full sentence containing a word
    /// - Parameters:
    ///   - text: The full text
    ///   - wordRange: The range of the word
    /// - Returns: The sentence containing the word
    func extractSentence(from text: String, containing wordRange: Range<String.Index>) -> String {
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        
        var sentence = ""
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if range.contains(wordRange.lowerBound) {
                sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                return false
            }
            return true
        }
        
        return sentence.isEmpty ? String(text[wordRange]) : sentence
    }
    
    /// Generate a cloze sentence by replacing the target word with blanks
    /// - Parameters:
    ///   - sentence: The original sentence
    ///   - word: The word to replace
    /// - Returns: Cloze sentence with the word replaced by [_____]
    func generateCloze(sentence: String, targetWord: String) -> String {
        // Case-insensitive replacement
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: targetWord))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return sentence
        }
        
        let range = NSRange(sentence.startIndex..., in: sentence)
        return regex.stringByReplacingMatches(in: sentence, range: range, withTemplate: "[_____]")
    }
}
