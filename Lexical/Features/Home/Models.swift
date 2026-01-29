import Foundation
import SwiftUI

struct Article: Identifiable {
    let id = UUID()
    let category: String
    let readTime: String
    let difficulty: String
    let title: String
    let content: String
    let imageUrl: String?
    let highlightedWords: [HighlightedWord]
    let tags: [String]
    
    // UI Helpers
    var categoryColor: Color {
        switch category.lowercased() {
        case "philosophy": return .blue.opacity(0.1)
        case "nature": return .green.opacity(0.1)
        case "music": return .purple.opacity(0.1)
        default: return .gray.opacity(0.1)
        }
    }
    
    var categoryTextColor: Color {
        switch category.lowercased() {
        case "philosophy": return .blue
        case "nature": return .green
        case "music": return .purple
        default: return .gray
        }
    }
}

struct HighlightedWord: Identifiable {
    let id = UUID()
    let word: String
    let definition: String
}

// Sample Data
extension Article {
    static let samples: [Article] = [
        Article(
            category: "Philosophy",
            readTime: "5 min read",
            difficulty: "Intermediate",
            title: "The Art of Serendipity",
            content: "Many of history's greatest discoveries were not the result of rigorous planning, but rather pure serendipity. It describes the occurrence of finding pleasant or desirable things when you aren't even looking for them.\n\nTo cultivate this mindset, one must remain open to the ephemeral moments of daily life.",
            imageUrl: "https://lh3.googleusercontent.com/aida-public/AB6AXuCbUUkzclZzEtOz2Jme5kmBHLCxrK1kkEEGgmixc_cFf2REQHCiFonpfRy9hihXFd2Pif03oifdQUThZbZpKX2jGtaLm8t8CHN3qioHaLkwLSQa5t7B7dtU3xpkntMXXvRmrpvdcsKtakBnHBNt9fziGluMx4XrlWOyXJdxq6IfBMG2qJJexrsevNOMwDDq8ZA9EW7cNdsSaiMmvCTWCzwWyiNyECI78waatyNwloOnsuEGHWD9DfxtpeC9ctz7vB3cHsk1LBIB2Vq9",
            highlightedWords: [
                HighlightedWord(word: "serendipity", definition: "Finding something good without looking for it"),
                HighlightedWord(word: "ephemeral", definition: "Lasting for a very short time")
            ],
            tags: ["Mindset", "History"]
        ),
        Article(
            category: "Nature",
            readTime: "4 min read",
            difficulty: "Advanced",
            title: "Bioluminescence in the Deep",
            content: "In the deepest reaches of the ocean, sunlight is nonexistent. Here, creatures have evolved to become luminous. They generate their own light through complex chemical reactions.",
            imageUrl: nil, // Text-only card in design
            highlightedWords: [
                HighlightedWord(word: "luminous", definition: "Full of or shedding light"),
                HighlightedWord(word: "quintessential", definition: "Representing the most perfect or typical example")
            ],
            tags: ["Biology", "Ocean"]
        ),
        Article(
            category: "Music",
            readTime: "6 min read",
            difficulty: "Intermediate",
            title: "The Physics of Sound",
            content: "A sonorous voice can captivate a room instantly. But what gives sound its depth and resonance? It begins with vibration.",
            imageUrl: "https://lh3.googleusercontent.com/aida-public/AB6AXuChNd1JkRbRfq-rEN-BHJiO0IJvDp13SSreVZ9HHiOf_HfgKUQx_wOLcIL5Y6uou-L7Nd_ytdcijMuO4TqgO2AZnToiF7OxcSnIh0AUbjUQh7o8F-rUUb5euSYgWcl8xNuqvFfQfLS96GpSf4TM8kN5-cU6H6_CNxCYg_hfkYHFEdzkKog-_rbqv-wBEH9jiGqIm-3bkoQlTty6gM43G4AP0Ob6JgjsSoC9Rw2uMmhtcSe3bOskJXorJ8iyPEyBFcuhIFK96H4Rw0bf",
            highlightedWords: [
                HighlightedWord(word: "sonorous", definition: "Imposingly deep and full")
            ],
            tags: ["Physics", "Acoustics"]
        )
    ]
}
