import SwiftUI
import LexicalCore

/// Two-sided flashcard with Liquid Glass design and 3D flip animation
struct FlashcardView: View {
    let spec: RecallFigmaSpec
    let colorScheme: ColorScheme
    let scale: CGFloat
    let item: ReviewCard
    let onFlip: () -> Void
    
    @Binding var isFlipped: Bool
    
    var body: some View {
        ZStack {
            // BACK (Answer)
            CardFace(
                spec: spec,
                colorScheme: colorScheme,
                scale: scale,
                title: "Answer",
                content: {
                    VStack(alignment: .center, spacing: 16 * scale) {
                        Text(displayWord(item.lemma))
                            .font(.system(size: spec.headerTitleFontSize * scale, weight: .medium, design: .default))
                            .foregroundStyle(spec.titleColor(for: colorScheme))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        
                        Divider()
                            .overlay(Color.primary.opacity(0.1))
                        
                        // Modified sentence with highlight
                        let answerSentence = generateAnswerSentence(sentence: item.contextSentence, targetResult: item.lemma)
                        Text(answerSentence)
                            .font(.system(size: spec.supportingFontSize * scale, weight: .regular))
                            .foregroundStyle(spec.titleColor(for: colorScheme))
                            .lineSpacing(4 * scale)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            )
            .rotation3DEffect(
                .degrees(isFlipped ? 0 : -180),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .opacity(isFlipped ? 1 : 0)
            
            // FRONT (Question)
            CardFace(
                spec: spec,
                colorScheme: colorScheme,
                scale: scale,
                title: "Complete the Sentence",
                content: {
                    VStack(alignment: .center, spacing: 12 * scale) {
                        Text(maskedSentence(item.contextSentence, lemma: item.lemma))
                            .font(.system(size: spec.sentenceFontSize * scale, weight: .regular, design: .default))
                            .foregroundStyle(spec.titleColor(for: colorScheme))
                            .lineSpacing(4 * scale)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            )
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .opacity(isFlipped ? 0 : 1)
        }
        .frame(minHeight: spec.cardMinHeight * scale)
        .onTapGesture {
            flipCard()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to flip the card.")
        .accessibilityAction(named: Text("Flip card")) {
            flipCard()
        }
    }
    
    private func generateAnswerSentence(sentence: String, targetResult: String) -> AttributedString {
        var str = AttributedString(sentence)
        let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: targetResult))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return str }
        
        // Find matches and bold them
        let nsString = sentence as NSString
        let results = regex.matches(in: sentence, range: NSRange(location: 0, length: nsString.length))
        
        for result in results {
            if let range = Range(result.range, in: sentence),
               let attrRange = str.range(of: String(sentence[range])) {
                str[attrRange].font = .system(size: spec.supportingFontSize * scale, weight: .bold)
            }
        }
        return str
    }

    private func generateCloze(sentence: String, target: String) -> LocalizedStringKey {
        let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: target))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return LocalizedStringKey(sentence)
        }
        let range = NSRange(sentence.startIndex..., in: sentence)
        let modified = regex.stringByReplacingMatches(
            in: sentence,
            range: range,
            withTemplate: "[_____]"
        )
        return LocalizedStringKey(modified)
    }

    private func flipCard() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isFlipped.toggle()
            if isFlipped { onFlip() }
        }
    }
}

/// Reusable Card Face Container
struct CardFace<Content: View>: View {
    let spec: RecallFigmaSpec
    let colorScheme: ColorScheme
    let scale: CGFloat
    let title: String
    let content: Content
    
    init(spec: RecallFigmaSpec, colorScheme: ColorScheme, scale: CGFloat, title: String, @ViewBuilder content: () -> Content) {
        self.spec = spec
        self.colorScheme = colorScheme
        self.scale = scale
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        GlassEffectContainer(material: colorScheme == .dark ? .ultraThin : .regular) {
            VStack(alignment: .center, spacing: 12 * scale) {
                Text(title.uppercased())
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(Color(hex: "525252"))
                    .tracking(0.2 * scale)
                    .accessibilityAddTraits(.isHeader)

                content
                
                Spacer()
            }
            .padding(.horizontal, 24 * scale)
            .padding(.vertical, 24 * scale)
            .frame(maxWidth: .infinity, minHeight: spec.cardMinHeight * scale, alignment: .top)
        }
        .clipShape(RoundedRectangle(cornerRadius: spec.cardCornerRadius * scale, style: .continuous))
        .background(Color(white: colorScheme == .dark ? 0.1 : 1.0, opacity: spec.figmaCardBackgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: spec.cardCornerRadius * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: spec.cardCornerRadius * scale, style: .continuous)
                .stroke(Color(white: colorScheme == .dark ? 0.3 : 1.0, opacity: spec.figmaCardBorderOpacity), lineWidth: max(1, 1.1 * scale))
        )
        .shadow(
            color: spec.cardDropShadowColor.opacity(0.1),
            radius: spec.cardDropShadowRadius * scale,
            x: 0,
            y: spec.cardDropShadowY * scale
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @Environment(\.colorScheme) private var colorScheme
        @State private var isFlipped = false
        var body: some View {
            let mockCard = ReviewCard(
                lemma: "serendipity",
                originalWord: "serendipity",
                contextSentence: "The discovery of the new star was a moment of serendipity.",
                definition: "The occurrence and development of events by chance in a happy or beneficial way.",
                stability: 1.0,
                difficulty: 1.0,
                retrievability: 1.0,
                nextReviewDate: Date(),
                lastReviewDate: Date(),
                reviewCount: 1,
                createdAt: Date(),
                status: .learning
            )
            
            FlashcardView(
                spec: RecallFigmaSpec(),
                colorScheme: colorScheme,
                scale: 1.0,
                item: mockCard,
                onFlip: {},
                isFlipped: $isFlipped
            )
            .padding(24)
        }
    }
    return PreviewWrapper()
}

