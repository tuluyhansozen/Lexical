import SwiftUI
import LexicalCore

/// Two-sided flashcard with Liquid Glass design and 3D flip animation
struct FlashcardView: View {
    let item: VocabularyItem
    let onFlip: () -> Void
    
    @Binding var isFlipped: Bool
    
    var body: some View {
        ZStack {
            // BACK (Answer)
            CardFace(
                title: "Answer",
                content: {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(item.lemma.capitalized)
                            .font(.display(size: 32, weight: .bold))
                            .foregroundStyle(Color.adaptiveText)
                        
                        Divider()
                        
                        Text(item.contextSentence)
                            .font(.bodyText)
                            .foregroundStyle(Color.adaptiveText.opacity(0.8))
                        
                        if let definition = item.definition {
                            Text(definition)
                                .font(.subheadline)
                                .italic()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            )
            .rotation3DEffect(
                .degrees(isFlipped ? 0 : -180),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .opacity(isFlipped ? 1 : 0)
            
            // FRONT (Question)
            CardFace(
                title: "Complete the Sentence",
                content: {
                    Text(generateCloze(sentence: item.contextSentence, target: item.originalWord))
                        .font(.display(size: 24, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveText)
                }
            )
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .opacity(isFlipped ? 0 : 1)
        }
        .frame(height: 400)
        .padding(24)
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isFlipped.toggle()
                if isFlipped { onFlip() }
            }
        }
    }
    
    private func generateCloze(sentence: String, target: String) -> LocalizedStringKey {
        // Simple case-insensitive replacement for display
        // In production, use range-based replacement to preserve case of surrounding text
        // For now, replacing the target word with a distinct placeholder
        let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: target))\\b"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(sentence.startIndex..., in: sentence)
        let modified = regex.stringByReplacingMatches(
            in: sentence,
            range: range,
            withTemplate: "**[_____]**" // Markdown bold for SwiftUI
        )
        return LocalizedStringKey(modified)
    }
}

/// Reusable Card Face Container
struct CardFace<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        GlassEffectContainer(material: .systemUltraThinMaterial) {
            VStack(spacing: 20) {
                Text(title.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                
                Spacer()
                
                content
                    .padding(.horizontal)
                
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(LinearGradient(
                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }
}
