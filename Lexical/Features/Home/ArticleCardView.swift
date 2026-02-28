import SwiftUI
import SwiftData
import LexicalCore

struct ArticleCardView: View {
    let article: GeneratedArticle
    @Environment(\.modelContext) private var modelContext
    @State private var showReader = false
    @State private var wordStatuses: [String: UserWordStatus] = [:]
    private let articleStore = ArticleStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category + Read Time row
            HStack(alignment: .center) {
                Text(article.category.uppercased())
                    .font(.system(size: 12, weight: .regular))
                    .tracking(0.617)
                    .foregroundStyle(Color(hex: "4A5565"))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .regular))
                    Text(estimatedReadTimeLabel)
                        .font(.system(size: 13, weight: .regular))
                        .tracking(0.617)
                }
                .foregroundStyle(Color(hex: "4A5565"))
                .accessibilityLabel("Estimated reading time \(estimatedReadTimeLabel)")
            }
            .padding(.top, 16)

            // Title
            Text(article.title)
                .font(.system(size: 18, weight: .semibold))
                .tracking(-0.44)
                .lineSpacing(28 - 18) // line-height 28 - font-size 18
                .foregroundStyle(Color(hex: "0A0A0A"))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.top, 7)
                .accessibilityAddTraits(.isHeader)

            // Excerpt with highlighted words
            Text(highlightedExcerpt)
                .font(.system(size: 14, weight: .regular))
                .tracking(-0.15)
                .lineSpacing(22.75 - 14) // line-height 22.75
                .foregroundStyle(Color(hex: "364153"))
                .padding(.top, 12)
                .lineLimit(5)

            Spacer(minLength: 8)

            // Continue Reading button
            Button {
                recordArticleExposure()
                showReader = true
            } label: {
                Text("Continue Reading \u{2192}")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.15)
                    .foregroundStyle(Color(red: 2/255, green: 17/255, blue: 5/255).opacity(0.71))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
            .accessibilityLabel("Continue reading \(article.title)")
            .accessibilityHint("Opens the full article reader.")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 253, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 4)
        .accessibilityElement(children: .contain)
        .task {
            loadWordStatuses()
        }
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
                            .accessibilityIdentifier("reader.closeButton")
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
                            .accessibilityIdentifier("reader.closeButton")
                        }
                    }
            }
        }
        #endif
    }

    private var highlightedExcerpt: AttributedString {
        var value = AttributedString(snippet)

        for word in article.targetWords {
            let sanitized = sanitizedToken(word)
            let status = wordStatuses[sanitized] ?? .new
            let color: Color
            switch status {
            case .known:
                // Green — Figma rgba(182,255,148,0.76)
                color = Color(red: 182/255, green: 1.0, blue: 148/255).opacity(0.76)
            case .learning:
                // Orange — Figma rgba(255,179,98,0.64)
                color = Color(red: 1.0, green: 179/255, blue: 98/255).opacity(0.64)
            case .new:
                // Red — Figma rgba(255,134,134,0.64)
                color = Color(red: 1.0, green: 134/255, blue: 134/255).opacity(0.64)
            case .ignored:
                continue // No highlight for ignored words
            }
            highlight(word: sanitized, color: color, in: &value)
        }

        return value
    }

    private func loadWordStatuses() {
        let lemmas = article.targetWords.map { sanitizedToken($0) }
        do {
            let activeUserId = UserProfile.resolveActiveProfile(modelContext: modelContext).userId
            let states = try modelContext.fetch(FetchDescriptor<UserWordState>())
            
            var statuses: [String: UserWordStatus] = [:]
            for state in states {
                if state.userId == activeUserId, lemmas.contains(state.lemma) {
                    statuses[state.lemma] = state.status
                }
            }
            wordStatuses = statuses
        } catch {
            print("Failed to fetch word states in ArticleCardView: \(error)")
        }
    }

    private var snippet: String {
        let compact = article.content
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let maxLength = 200
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
        content: "The cacophony of street vendors gave way to serendipity when she stumbled upon a quiet courtyard. A melancholy tune drifted from an open window, its ephemeral notes dissolving into the evening air before anyone could catch them.",
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

    // Seed mock word states with different statuses for color testing
    let userId = UserProfile.fallbackLocalUserID
    let profile = UserProfile(userId: userId)
    container.mainContext.insert(profile)

    let knownWord = UserWordState(userId: userId, lemma: "cacophony", status: .known)
    let learningWord = UserWordState(userId: userId, lemma: "serendipity", status: .learning)
    let newWord = UserWordState(userId: userId, lemma: "melancholy", status: .new)
    let ignoredWord = UserWordState(userId: userId, lemma: "ephemeral", status: .ignored)
    container.mainContext.insert(knownWord)
    container.mainContext.insert(learningWord)
    container.mainContext.insert(newWord)
    container.mainContext.insert(ignoredWord)

    return ScrollView {
        ArticleCardView(article: mockArticle)
            .padding(.horizontal, 16)
    }
    .background(Color.adaptiveBackground)
    .modelContainer(container)
}
