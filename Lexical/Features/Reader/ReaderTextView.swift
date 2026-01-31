import SwiftUI
import UIKit

/// TextKit 2 based reader view with vocabulary highlighting
struct ReaderTextView: UIViewRepresentable {
    let text: String
    let vocabularyStates: [String: VocabularyState]
    let onWordTap: (String, String, Range<String.Index>) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        
        // Add tap gesture for word selection
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        textView.addGestureRecognizer(tapGesture)
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Apply attributed string with vocabulary highlighting
        let attributedText = createAttributedText()
        textView.attributedText = attributedText
        context.coordinator.text = text
        context.coordinator.vocabularyStates = vocabularyStates
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: text, vocabularyStates: vocabularyStates, onWordTap: onWordTap)
    }
    
    private func createAttributedText() -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Base attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        paragraphStyle.paragraphSpacing = 16
        
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        
        attributedString.addAttributes(
            baseAttributes,
            range: NSRange(location: 0, length: text.count)
        )
        
        // Apply vocabulary-based highlighting
        for (word, state) in vocabularyStates {
            highlightWord(word, state: state, in: attributedString)
        }
        
        return attributedString
    }
    
    private func highlightWord(_ word: String, state: VocabularyState, in attributedString: NSMutableAttributedString) {
        let text = attributedString.string.lowercased()
        let searchWord = word.lowercased()
        var searchRange = text.startIndex..<text.endIndex
        
        while let range = text.range(of: searchWord, options: .caseInsensitive, range: searchRange) {
            let nsRange = NSRange(range, in: text)
            
            let backgroundColor: UIColor
            switch state {
            case .new:
                backgroundColor = UIColor(red: 0.89, green: 0.95, blue: 0.99, alpha: 1.0) // #E3F2FD
            case .learning:
                backgroundColor = UIColor(red: 1.0, green: 0.98, blue: 0.77, alpha: 1.0) // #FFF9C4
            case .known:
                backgroundColor = .clear
            case .unknown:
                backgroundColor = UIColor.systemGray6
            }
            
            if state != .known {
                attributedString.addAttributes([
                    .backgroundColor: backgroundColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: backgroundColor.withAlphaComponent(0.5)
                ], range: nsRange)
            }
            
            searchRange = range.upperBound..<text.endIndex
        }
    }
    
    class Coordinator: NSObject {
        var text: String
        var vocabularyStates: [String: VocabularyState]
        let onWordTap: (String, String, Range<String.Index>) -> Void
        
        init(text: String, vocabularyStates: [String: VocabularyState], onWordTap: @escaping (String, String, Range<String.Index>) -> Void) {
            self.text = text
            self.vocabularyStates = vocabularyStates
            self.onWordTap = onWordTap
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            
            let location = gesture.location(in: textView)
            let position = textView.closestPosition(to: location) ?? textView.beginningOfDocument
            
            // Get word at tap position
            guard let wordRange = textView.tokenizer.rangeEnclosingPosition(
                position,
                with: .word,
                inDirection: UITextDirection(rawValue: UITextLayoutDirection.right.rawValue)
            ) else { return }
            
            guard let word = textView.text(in: wordRange) else { return }
            
            // Convert to String.Index range
            let startOffset = textView.offset(from: textView.beginningOfDocument, to: wordRange.start)
            let endOffset = textView.offset(from: textView.beginningOfDocument, to: wordRange.end)
            
            guard let startIndex = text.index(text.startIndex, offsetBy: startOffset, limitedBy: text.endIndex),
                  let endIndex = text.index(text.startIndex, offsetBy: endOffset, limitedBy: text.endIndex) else {
                return
            }
            
            let range = startIndex..<endIndex
            
            // Extract sentence context
            let sentence = extractSentence(containing: range)
            
            onWordTap(word, sentence, range)
        }
        
        private func extractSentence(containing range: Range<String.Index>) -> String {
            // Find sentence boundaries
            var start = range.lowerBound
            var end = range.upperBound
            
            // Search backward for sentence start
            while start > text.startIndex {
                let prev = text.index(before: start)
                let char = text[prev]
                if char == "." || char == "!" || char == "?" {
                    break
                }
                start = prev
            }
            
            // Search forward for sentence end
            while end < text.endIndex {
                let char = text[end]
                if char == "." || char == "!" || char == "?" {
                    end = text.index(after: end)
                    break
                }
                end = text.index(after: end)
            }
            
            return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
