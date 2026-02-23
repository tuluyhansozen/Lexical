import SwiftUI
import SwiftData
import LexicalCore

struct ArticleCardView: View {
    let article: GeneratedArticle
    @Environment(\.modelContext) private var modelContext
    @State private var showReader = false
    private let articleStore = ArticleStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(article.category.uppercased())
                    .font(.caption2)
                    .tracking(0.62)
                    .foregroundStyle(Color.adaptiveTextSecondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .regular))
                    Text(estimatedReadTimeLabel)
                        .font(.caption2)
                }
                .foregroundStyle(Color.adaptiveTextSecondary)
                .accessibilityLabel("Estimated reading time \(estimatedReadTimeLabel)")
            }
            .padding(.top, 14)

            Text(article.title)
                .font(.cardTitle)
                .foregroundStyle(Color.adaptiveText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            Text(highlightedExcerpt)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(Color.adaptiveTextSecondary)
                .padding(.top, 12)
                .lineLimit(4)

            Spacer(minLength: 14)

            Button {
                recordArticleExposure()
                showReader = true
            } label: {
                Text("Continue Reading \u{2192}")
                    .font(.headline)
                    .foregroundStyle(Color.sonPrimary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 25)
            .accessibilityLabel("Continue reading \(article.title)")
            .accessibilityHint("Opens the full article reader.")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 253, alignment: .topLeading)
        .background(Color.adaptiveSurfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.adaptiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 4)
        .accessibilityElement(children: .contain)
        #if os(iOS)
        .fullScreenCover(isPresented: $showReader) {
            NavigationStack {
                ReaderView(
                    title: article.title,
                    content: article.content,
                    focusLemmas: article.targetWords
                )
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                showReader = false
                            }
                            .accessibilityLabel("Close reader")
                        }
                    }
            }
        }
        #else
        .sheet(isPresented: $showReader) {
            NavigationStack {
                ReaderView(
                    title: article.title,
                    content: article.content,
                    focusLemmas: article.targetWords
                )
                    .toolbar {
                        ToolbarItem {
                            Button("Close") {
                                showReader = false
                            }
                            .accessibilityLabel("Close reader")
                        }
                    }
            }
        }
        #endif
    }

    private var highlightedExcerpt: AttributedString {
        var value = AttributedString(snippet)
        let palette: [Color] = [
            Color(hex: "FFC6F3"),
            Color(red: 182.0 / 255.0, green: 1.0, blue: 148.0 / 255.0).opacity(0.76),
            Color(red: 1.0, green: 179.0 / 255.0, blue: 98.0 / 255.0).opacity(0.64),
            Color(red: 121.0 / 255.0, green: 177.0 / 255.0, blue: 1.0).opacity(0.78)
        ]

        for (index, word) in article.targetWords.prefix(palette.count).enumerated() {
            highlight(word: sanitizedToken(word), color: palette[index], in: &value)
        }

        return value
    }

    private var snippet: String {
        let compact = article.content
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let maxLength = 140
        guard compact.count > maxLength else { return compact }

        let limitIndex = compact.index(compact.startIndex, offsetBy: maxLength)
        let prefix = compact[..<limitIndex]
        if let split = prefix.lastIndex(of: " ") {
            return String(prefix[..<split])
        }
        return String(prefix)
    }

    private var estimatedReadTimeLabel: String {
        let wordCount = max(1, article.content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count)
        let fastMinutes = max(1, Int(ceil(Double(wordCount) / 140.0)))
        let slowMinutes = max(fastMinutes, Int(ceil(Double(wordCount) / 110.0)))
        if fastMinutes == slowMinutes {
            return "\(fastMinutes) min read"
        }
        return "\(fastMinutes)-\(slowMinutes) min read"
    }

    private func highlight(word: String, color: Color, in text: inout AttributedString) {
        guard !word.isEmpty else { return }
        guard let range = text.range(of: word, options: .caseInsensitive) else { return }
        text[range].backgroundColor = color
    }

    private func sanitizedToken(_ raw: String) -> String {
        raw.lowercased()
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }

    @MainActor
    private func recordArticleExposure() {
        Task {
            await articleStore.markViewed(article.id)
        }

        let uniqueLemmas = Array(
            Set(
                article.targetWords
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        )

        guard !uniqueLemmas.isEmpty else { return }

        for lemma in uniqueLemmas {
            do {
                _ = try ReviewWriteCoordinator.submitImplicitExposure(
                    lemma: lemma,
                    modelContext: modelContext
                )
            } catch {
                print("ArticleCardView: failed implicit exposure write for '\(lemma)': \(error)")
            }
        }
    }
}

#Preview {
    let mockArticle = GeneratedArticle(
        id: UUID(),
        title: "The Symphony of Silence",
        content: "In the heart of the bustling city, there exists a unique phenomenon known as the \"Symphony of Silence.\" This phrase encapsulates the rare moments of profound quiet that blanket the urban landscape.",
        targetWords: ["cacophony", "serendipity", "melancholy", "ephemeral"],
        category: "culture",
        generatedDate: Date(),
        difficultyScore: 0.65,
        targetRank: 500,
        isSaved: false
    )

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self, 
             UserWordState.self, 
             ReviewEvent.self, 
             UsageLedger.self, 
             LexemeDefinition.self,
             InterestProfile.self,
             GeneratedContent.self,
             MorphologicalRoot.self,
             DiscoveredLexeme.self,
        configurations: config
    )

    return ArticleCardView(article: mockArticle)
        .padding()
        .modelContainer(container)
}

